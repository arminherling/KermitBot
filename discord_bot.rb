# frozen_string_literal: true

require 'discordrb'
require 'net/http'
require 'json'
require 'configatron'
require_relative 'config'

ARROW_LEFT = '◀'
ARROW_RIGHT =  '▶'
CROSS_MARK = '❌'

uri = URI('https://customsearch.googleapis.com/customsearch/v1')

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

bot.command :g do |event, *parameters|
  command_parameter = parameters.join(' ')
  if command_parameter.empty?
    event.channel.send_message 'You forgot to type what you want to search for!'
    event.channel.send_message '<:kermitwtf:1085519892993810482>'
    return nil
  end

  unless event.message.mentions.empty?
    event.channel.send_message 'Can\' search for discord mentions!'
    event.channel.send_message '<:kermitwtf:1085519892993810482>'
    return nil
  end

  google_params = { gl: 'en', cx: configatron.google_cx, key: configatron.google_api, q: command_parameter }

  uri.query = URI.encode_www_form(google_params)
  response = Net::HTTP.get_response(uri)
  body = JSON.parse(response.body)

  if body.key?('error')
    event.channel.send_message 'Cant search anymore for today, try again tomorrow!'
    return nil
  end

  items = body['items']
  current_item = 0
  total_items = items.length

  result = items[current_item]
  formatted_total_results = body['searchInformation']['formattedTotalResults']

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
