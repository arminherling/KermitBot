# frozen_string_literal: true

def parse_carl_bot_message(message, database)
  server_id = message.server.id

  split = message.content.split

  maybe_number_string = split[1]
  maybe_number_string.gsub! '**', ''

  star_count = Integer(maybe_number_string, exception: false)
  star_count = 1 if star_count.nil?

  channel_name = split[1] if star_count == 1
  channel_name = split[2] unless star_count == 1
  channel_id = channel_name.gsub('<#', '').gsub('>', '')

  return if message.embeds.empty?

  embed = message.embeds[0]

  content = embed.description
  message_time = embed.timestamp

  embed_author = embed.author
  author_name = embed_author.name
  author_icon = embed_author.icon_url

  embed_footer = embed.footer
  message_id = Integer(embed_footer.text, exception: false)
  message_id = nil if message_id.nil?

  embed_image = embed.image
  embed_image_url = nil
  embed_image_url = embed_image.url unless embed_image.nil?

  jump_link = nil
  attachment_link = nil

  embed.fields&.each do |f|
    if f.name.casecmp('Source').zero?
      jump_link = f.value
    elsif f.name.casecmp('Attachment').zero?
      attachment_link = f.value
    end
  end

  database.insert_starboard(
    star_count,
    message_id,
    channel_id,
    server_id,
    nil,
    content,
    message_time,
    author_name,
    author_icon,
    embed_image_url,
    jump_link,
    attachment_link
  )
end

def parse_ragnarok_bot_message(message, database)
  server_id = message.server.id

  split = message.content.split

  maybe_number_string = split[1]
  maybe_number_string.gsub! '**', ''

  star_count = Integer(maybe_number_string, exception: false)
  star_count = 1 if star_count.nil?

  channel_name = split[1] if star_count == 1
  channel_name = split[2] unless star_count == 1
  channel_id = channel_name.gsub('<#', '').gsub('>', '')

  message_id = split[3] if star_count == 1
  message_id = split[4] unless star_count == 1

  return if message.embeds.empty?

  embed = message.embeds[0]

  content = embed.description
  message_time = embed.timestamp

  embed_author = embed.author
  author_name = embed_author.name
  author_icon = embed_author.icon_url

  embed_image = embed.image
  embed_image_url = nil
  embed_image_url = embed_image.url unless embed_image.nil?

  database.insert_starboard(
    star_count,
    message_id,
    channel_id,
    server_id,
    nil,
    content,
    message_time,
    author_name,
    author_icon,
    embed_image_url,
    nil,
    nil
  )
end
