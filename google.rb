# frozen_string_literal: true

require 'net/http'
require 'json'

ARROW_LEFT = '◀'
ARROW_RIGHT =  '▶'
CROSS_MARK = '❌'

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

def search_google(query, config)
  google_search_url = URI('https://customsearch.googleapis.com/customsearch/v1')
  google_params = { gl: 'en', cx: config.google_cx, key: config.google_api, q: query }

  google_search_url.query = URI.encode_www_form(google_params)
  response = Net::HTTP.get_response(google_search_url)
  body = JSON.parse(response.body)

  return nil if body.key?('error')

  body
end
