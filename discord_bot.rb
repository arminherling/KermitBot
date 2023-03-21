# frozen_string_literal: true

require_relative 'database'
require 'discordrb'
require 'net/http'
require 'json'
require 'configatron'
require_relative 'config'

ARROW_LEFT = '◀'
ARROW_RIGHT =  '▶'
CROSS_MARK = '❌'

KERMIT_REACTIONS = [
  '<:DangKermit:1085642449407459348>',
  '<:Kermit:1085642451953405992>',
  '<:KermitBlush:1085642453689835540>',
  '<:KermitBoss:1085642457934475345>',
  '<:KermitBruh:1085642460933390356>',
  '<:KermitCartoon:1085636582268223488>',
  '<:KermitCartoon2:1085642462569185310>',
  '<a:KermitDance:1085642466671214722>',
  '<:KermitDerp:1085642470127312946>',
  '<:KermitDerp2:1085642472669069413>',
  '<a:KermitDrink:1085635351130951710>',
  '<a:KermitFancy:1085635631809577021>',
  '<:KermitFancyPog:1085642476154527814>',
  '<:KermitGirl:1085636579093135440>',
  '<:KermitGod:1085642478499143801>',
  '<:KermitHeh:1085642480659202229>',
  '<:KermitHm:1085642483230310470>',
  '<a:KermitHmpf:1085636151056023552>',
  '<:KermitHuh:1085642484845125673>',
  '<a:KermitInfinite:1085642488057966733>',
  '<:KermitMad:1085642489588887602>',
  '<:KermitPog:1085642492642328756>',
  '<:KermitPonder:1085643211093053510>',
  '<:KermitScared:1085642497017004062>',
  '<:KermitSmile:1085642498585677944>',
  '<:KermitStare:1085643212523319336>',
  '<:KermitSunglasses:1085642502603817070>',
  '<:KermitTea:1085642505128775761>',
  '<a:KermitTeeth:1085642508819767327>',
  '<:KermitTeeth2:1085643214968598718>',
  '<:KermitTeeth3:1085642512867262494>',
  '<:KermitThink:1085642515841044510>',
  '<a:KermitWho:1085642519217459220>',
  '<:KermitWtf:1085519892993810482>',
  '<:KermitYawn:1085643216524677210>'
].freeze

database = Database.new 'database.sqlite'
database.migrate Pathname.pwd.join 'Sql'

bot_mentions_regex = /(<@407595570232950786>|<@272452671414337536>)/

bot = Discordrb::Commands::CommandBot.new token: configatron.discord_token, prefix: ['k.', 'K.']

def chatgpt_allowed?(channel)
  return false if configatron.chatgpt_channel_blocklist.include? channel.id

  true
end

def key_and_is_url?(array, key)
  return false unless array.key?(key)

  return false unless array[key].start_with?('http')

  true
end

def get_thumbnail(google_result)
  return unless google_result.key? 'pagemap'

  pagemap = google_result['pagemap']

  if pagemap.key?('cse_image')
    cse_images = pagemap['cse_image']
    return unless cse_images.length >= 1

    cse_image = cse_images[0]
    return Discordrb::Webhooks::EmbedThumbnail.new url: cse_image['src'] if key_and_is_url?(cse_image, 'src')

  elsif pagemap.key?('metatags')
    metatags = pagemap['metatags']
    return unless metatags.length >= 1

    metatag = metatags[0]
    return Discordrb::Webhooks::EmbedThumbnail.new url: metatag['og:image'] if key_and_is_url?(metatag, 'og:image')

    return Discordrb::Webhooks::EmbedThumbnail.new url: metatag['image'] if key_and_is_url?(metatag, 'image')
  end
end

def get_description(google_result)
  return nil unless google_result.key? 'snippet'

  snippit = google_result['snippet'].split(' ... ')
  return snippit[1] if snippit.length == 2
  return google_result['snippet'] if snippit.length == 1
end

def create_embed_for_result(google_query, google_result, current_item, total_items, total_results)
  Discordrb::Webhooks::Embed.new(
    title: google_result['title'],
    description: get_description(google_result),
    # timestamp: Time.now,
    color: 0x5cb200,
    footer: Discordrb::Webhooks::EmbedFooter.new(text: "#{current_item + 1} of #{total_items} - Total results: #{total_results}"),
    thumbnail: get_thumbnail(google_result),
    author: Discordrb::Webhooks::EmbedAuthor.new(name: "Kermit Search: #{google_query}"),
    fields: [
      Discordrb::Webhooks::EmbedField.new(name: 'Link:', value: google_result['link'])
    ]
  )
end

def create_buttons_for_google(current_item, total_items)
  view = Discordrb::Webhooks::View.new
  view.row do |row|
    row.button(emoji: ARROW_LEFT, style: :primary, custom_id: ARROW_LEFT, disabled: current_item.zero?)
    row.button(emoji: ARROW_RIGHT, style: :primary, custom_id: ARROW_RIGHT, disabled: current_item + 1 == total_items)
    row.button(emoji: CROSS_MARK, style: :secondary, custom_id: CROSS_MARK)
  end
  view
end

def replace_mentions(message, content)
  unless message.nil?
    message.mentions.each do |user|
      content = content.gsub "<@#{user.id}>", user.name.tr(' ', '_')
    end

    message.role_mentions.each do |role|
      content = content.gsub "<@&#{role.id}>", role.name.tr(' ', '_')
    end
  end

  content.gsub! '@everyone', 'everyone'
  content.gsub! '@here', 'here'

  content
end

def split_messages(str, max_length = 1000)
  return [] if str.nil?

  chunks = []
  until str.empty?
    if str.length < max_length
      chunks.push str
      return chunks
    end
    size = str.rindex(' ', max_length)

    if !size.nil?
      chunks.push str.slice! 0, size + 1
    else
      chunks.push str
      return chunks
    end
  end
end

def search_google(query)
  google_search_url = URI('https://customsearch.googleapis.com/customsearch/v1')
  google_params = { gl: 'en', cx: configatron.google_cx, key: configatron.google_api, q: query }

  google_search_url.query = URI.encode_www_form(google_params)
  response = Net::HTTP.get_response(google_search_url)
  body = JSON.parse(response.body)

  return nil if body.key?('error')

  body
end

def ask_chat_gpt(messages)
  chat_gpt_url = URI('https://api.openai.com/v1/chat/completions')
  query_body = { model: 'gpt-3.5-turbo', messages: messages }
  chat_gpt_header = { 'Content-Type': 'application/json', 'Authorization': "Bearer #{configatron.chatgpt_token}" }

  response = Net::HTTP.post(chat_gpt_url, query_body.to_json, chat_gpt_header)
  return nil unless response.is_a?(Net::HTTPSuccess)

  body = JSON.parse(response.body)
  puts response.body
  return nil unless body.key? 'choices'

  choices = body['choices']
  return nil if choices.empty?

  message = choices[0]['message']
  return nil unless message.key? 'content'

  message['content'].strip
end

def maybe_send_random_emoji(channel)
  channel.send_message KERMIT_REACTIONS.sample if rand < 0.35
end

bot.mention start_with: bot_mentions_regex do |event|
  next nil unless chatgpt_allowed? event.channel

  event.channel.start_typing

  message_without_mention = event.content.sub bot_mentions_regex, ''
  trimmed_message = replace_mentions(event.message, message_without_mention)

  messages = []
  messages.push({ role: 'system', content: 'Pretend you are a Kermit the Frog. You are in an online chat, called \"Discord\".' })
  messages.push({ role: 'user', content: 'Hi.' }) if trimmed_message.empty?
  messages.push({ role: 'user', content: trimmed_message }) unless trimmed_message.empty?

  begin
    chat_response = ask_chat_gpt messages
  rescue Net::ReadTimeout => exception
    puts exception
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

  google_result = search_google(command_parameter)

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

def character_length(object)
  case object
  when NilClass
    3
  when Integer
    object.to_s.length
  when String
    object.length
  end
end

def column_sizes(array)
  keys = array[0].keys
  sizes = []
  keys.each do |key|
    max_hash = array.max_by do |hash|
      character_length hash[key]
    end

    sizes << character_length(max_hash[key])
  end
  sizes
end

def array_to_discord_code_block(array)
  return '```[]```' if array.empty?

  keys = array[0].keys

  header = Hash[keys.map {|x| [x, x]}]
  array_with_header = array + [header]
  sizes = column_sizes array_with_header
  code_block = +'```'

  keys.each_with_index do |key, index|
    code_block << " #{key.ljust(sizes[index])} "
    code_block << '|' unless index + 1 == keys.length
    code_block << "\n" if index + 1 == keys.length
  end

  total_size = sizes.sum + (keys.count * 2) + keys.count - 1

  code_block << +'-' * total_size
  code_block << "\n"

  array.each do |value|
    value.keys.each_with_index do |key, index|
      case value[key]
      when NilClass
        code_block << " #{'nil'.to_s.ljust(sizes[index])} "
      when Integer
        code_block << " #{value[key].to_s.ljust(sizes[index])} "
      when String
        code_block << " #{value[key].ljust(sizes[index])} "
      end

      code_block << '|' unless index + 1 == value.length
      code_block << "\n" if index + 1 == value.length
    end
  end

  code_block << '```'
  code_block
end

bot.command :sql, description: 'Executes an SQL query.', usage: 'k.sql SELECT * FROM VERSIONS' do |event, *parameters|
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

bot.command :eval, description: 'Evaluates a string as Ruby code.', usage: 'k.eval 2 + 2' do |event, *parameters|
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
    message << "Output: ```#{output}```" unless output.empty?
    message << "\n" unless output.empty?
    message << "Result: ```#{result}```" unless result.to_s.empty?
    message
  rescue Exception => e
    "Evaluation failed: #{e}"
  end
end

bot.run
