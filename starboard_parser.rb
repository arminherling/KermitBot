# frozen_string_literal: true

STAR = '⭐'

def insert_starboard_reactions(server, channel_id, message_id, database)
  found_channel = server.channels.find do |x|
    x.id == channel_id
  end
  if found_channel.nil?
    puts "Channel '#{channel_id}' could not be found."
    return
  end

  message = found_channel.load_message message_id
  if message.nil?
    puts "Message '#{message_id}' could not be found."
    return
  end

  author_id = message.author.id
  star_reactions = message.reacted_with STAR

  star_reactions.each do |user|
    database.insert_starboard_reaction(
      server.id,
      channel_id,
      message_id,
      author_id,
      user.id
    )
  end
end

def parse_carl_bot_message(message, database)
  server_id = message.server.id

  split = message.content.split

  maybe_number_string = split[1]
  maybe_number_string.gsub! '**', ''

  star_count = Integer(maybe_number_string, exception: false)
  star_count = 1 if star_count.nil?

  channel_name = split[1] if star_count == 1
  channel_name = split[2] unless star_count == 1
  channel_id_string = channel_name.gsub('<#', '').gsub('>', '')
  channel_id = Integer(channel_id_string, exception: false)

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
    server_id,
    channel_id,
    message_id,
    nil,
    content,
    message_time,
    author_name,
    author_icon,
    embed_image_url,
    jump_link,
    attachment_link
  )

  insert_starboard_reactions message.server, channel_id, message_id, database
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
  channel_id_string = channel_name.gsub('<#', '').gsub('>', '')
  channel_id = Integer(channel_id_string, exception: false)

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
    server_id,
    channel_id,
    message_id,
    nil,
    content,
    message_time,
    author_name,
    author_icon,
    embed_image_url,
    nil,
    nil
  )

  insert_starboard_reactions message.server, channel_id, message_id, database
end
