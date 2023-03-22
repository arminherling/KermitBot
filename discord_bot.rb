# frozen_string_literal: true

require_relative 'chat'
require_relative 'database'
require_relative 'discord_utils'
require_relative 'google'
require 'discordrb'
require 'configatron'
require_relative 'config'

database = Database.new 'database.sqlite'
database.migrate Pathname.pwd.join 'Sql'

bot = Discordrb::Commands::CommandBot.new token: configatron.discord_token, prefix: ['k.', 'K.']

def chatgpt_allowed?(channel)
  return false if configatron.chatgpt_channel_blocklist.include? channel.id

  true
end

bot_mentions_regex = /(<@407595570232950786>|<@272452671414337536>)/

bot.mention start_with: bot_mentions_regex do |event|
  next nil unless chatgpt_allowed? event.channel

  event.channel.start_typing

  message_without_mention = event.content.sub bot_mentions_regex, ''
  trimmed_message = replace_mentions(event.message, message_without_mention)

  messages = []
  messages.push({ role: 'system', content: 'Pretend you are a Kermit the Frog. You are in a discord chat, use emojis very rarely while talking.' })
  messages.push({ role: 'user', content: 'Hi.' }) if trimmed_message.empty?
  messages.push({ role: 'user', content: trimmed_message }) unless trimmed_message.empty?

  begin
    chat_response = ask_chat_gpt messages, configatron
  rescue Net::ReadTimeout => e
    puts e
    event.channel.send_message 'Oh, sorry about that. Can you please repeat what you asked me? This little froggy may have dozed off for a moment there.'
    next nil
  end

  response_message = split_messages chat_response

  if response_message.nil?
    event.channel.send_temporary_message 'Sorry I\'m busy right now.', 30
    next nil
  end

  response_message.each do |part|
    event.channel.send_message part
  end

  maybe_send_random_emoji event.channel
end

bot.command :fact, description: 'Kermit asks ChatGPT for a random fact.', usage: 'k.fact [Optional topic]' do |event, *parameters|
  event.channel.start_typing

  command_parameter = replace_mentions(event.message, parameters.join(' '))

  messages = []
  messages.push({ role: 'system', content: 'Pretend you are a Kermit the Frog. You are in a discord chat, use emojis very rarely while talking.' })
  messages.push({ role: 'user', content: 'Tell me a random fact.' }) if command_parameter.empty?
  messages.push({ role: 'user', content: "Tell me a random fact about \"#{command_parameter}\"" }) unless command_parameter.empty?

  random_fact = ask_chat_gpt(messages)

  if random_fact.nil?
    event.channel.send_temporary_message 'Hmmm, I can\'t think of one right now.', 30
    event.channel.send_temporary_message '<:KermitDerp2:1085642472669069413>', 30
    return nil
  end

  event.channel.send_message random_fact
  event.channel.send_message KERMIT_REACTIONS.sample
end

bot.command :g, description: 'Shows the first 10 Google results for a topic.', usage: 'k.g [words to search for]' do |event, *parameters|
  event.channel.start_typing

  command_parameter = replace_mentions(event.message, parameters.join(' '))
  if command_parameter.empty?
    event.channel.send_message 'You forgot to type what you want to search for!'
    event.channel.send_message '<:KermitWtf:1085519892993810482>'
    return nil
  end

  google_result = search_google command_parameter, configatron

  if google_result.nil?
    event.channel.send_message 'Cant search anymore for today, try again tomorrow!'
    return nil
  end

  items = google_result['items']
  current_item = 0
  total_items = items.length

  result = items[current_item]
  formatted_total_results = google_result['searchInformation']['formattedTotalResults']

  first_item_embed = create_embed_for_result(command_parameter, result, current_item, total_items, formatted_total_results)
  components = create_buttons_for_google(current_item, total_items)

  message = event.channel.send_message '', false, first_item_embed, nil, nil, nil, components

  bot.add_await!(Discordrb::Events::ButtonEvent, timeout: 120) do |reaction_event|
    next false unless reaction_event.message.id == message.id

    if reaction_event.user.id != event.author.id
      reaction_event.respond(content: "Only #{event.author.name} can respond to this message!", ephemeral: true)
      next false
    end

    custom_id = reaction_event.custom_id
    case custom_id
    when ARROW_LEFT
      reaction_event.defer_update

      next false if (current_item - 1) == -1

      current_item -= 1
      result = items[current_item]
      new_embed = create_embed_for_result(command_parameter, result, current_item, total_items, formatted_total_results)
      new_components = create_buttons_for_google(current_item, total_items)

      message.edit('', new_embed, new_components)

      next false
    when ARROW_RIGHT
      reaction_event.defer_update

      next false unless current_item + 1 != total_items

      current_item += 1
      result = items[current_item]
      new_embed = create_embed_for_result(command_parameter, result, current_item, total_items, formatted_total_results)
      new_components = create_buttons_for_google(current_item, total_items)
      message.edit('', new_embed, new_components)

      next false
    when CROSS_MARK
      next true
    end
  end

  current_embed = create_embed_for_result(command_parameter, result, current_item, total_items, formatted_total_results)
  message.edit(nil, current_embed, Discordrb::Webhooks::View.new)

  nil
end

bot.command :sql, help_available: false, description: 'Executes an SQL query.', usage: 'k.sql SELECT * FROM VERSIONS' do |event, *parameters|
  return nil unless bot.bot_application.owner.id == event.user.id

  command_parameter = parameters.join(' ')
  # remove code block markdown symbols
  command_parameter.delete_prefix! '```sql'
  command_parameter.delete_prefix! '```'
  command_parameter.delete_suffix! '```'

  # remove code line markdown symbols
  command_parameter.delete_prefix! '``'
  command_parameter.delete_suffix! '``'
  command_parameter.strip!

  return nil if command_parameter.empty?

  sql_parts = command_parameter.split ' '

  result = []
  begin
    if command_parameter.downcase.start_with? 'tables'

      # get all table names
      result = database.execute "SELECT name FROM sqlite_master WHERE type='table'"
    elsif command_parameter.downcase.start_with?('columns') && sql_parts.count >= 2

      # get all column names and types for a table
      result = database.execute "PRAGMA table_info(#{sql_parts[1]})"
      next "No such table: #{sql_parts[1]}" if result.empty?

    else

      # execute the given query
      result = database.execute command_parameter
    end

    return '[]' if result.empty?

    array_to_discord_code_block result
  rescue SQLite3::Exception => e
    "Transaction failed: #{e}"
  end
end

def eval_and_capture_stdout(code)
  out = StringIO.new
  $stdout = out
  result = eval(code)
  $stdout = STDOUT
  [out.string, result]
end

bot.command :eval, help_available: false, description: 'Evaluates a string as Ruby code.', usage: 'k.eval 2 + 2' do |event, *parameters|
  return nil unless bot.bot_application.owner.id == event.user.id

  command_parameter = parameters.join(' ')
  # remove code block markdown symbols
  command_parameter.delete_prefix! '```rb'
  command_parameter.delete_prefix! '```'
  command_parameter.delete_suffix! '```'

  # remove code line markdown symbols
  command_parameter.delete_prefix! '``'
  command_parameter.delete_suffix! '``'
  command_parameter.strip!

  return nil if command_parameter.empty?

  begin
    output, result = eval_and_capture_stdout(command_parameter)

    message = +''
    message << "Output: ```\n#{output}```" unless output.empty?
    message << "\n" unless output.empty?
    message << "Result: ```\n#{result}```" unless result.to_s.empty?
    message
  rescue Exception => e
    "Evaluation failed: #{e}"
  end
end

bot.command :chat, help_available: false, description: 'Various settings for the chatGPT bot' do |event, *parameters|
  "eval 2"
end

bot.run
