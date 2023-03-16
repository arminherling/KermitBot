# frozen_string_literal: true

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

bot = Discordrb::Commands::CommandBot.new token: configatron.discord_token, prefix: ['k.', 'K.']

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
  return nil unless body.key? 'choices'

  choices = body['choices']
  return nil if choices.empty?

  message = choices[0]['message']
  return nil unless message.key? 'content'

  message['content'].strip
end

bot.command :fact, description: 'Kermit asks ChatGPT for a random fact.', usage: 'k.fact [Optional topic]' do |event, *parameters|
  event.channel.start_typing

  command_parameter = replace_mentions(event.message, parameters.join(' '))

  messages = []
  messages.push({ role: 'system', content: 'You are Kermit the frog. You are in an online chat, called \"Discord\".' })
  messages.push({ role: 'user', content: 'Tell me a random fact.' }) if command_parameter.empty?
  messages.push({ role: 'user', content: "Tell me a random fact about \"#{command_parameter}\"" }) unless command_parameter.empty?

  random_fact = ask_chat_gpt(messages)

  if random_fact.nil?
    event.channel.send_message 'Hmmm, I can\'t think of one right now.'
    event.channel.send_message '<:KermitDerp2:1085642472669069413>'
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

bot.run
