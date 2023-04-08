# frozen_string_literal: true

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

def maybe_send_random_emoji(channel)
  channel.send_message KERMIT_REACTIONS.sample if rand < 0.35
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
  header = Hash[keys.map { |x| [x, x] }]
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

def create_embed_for_member_info(member, server, database)
  avatar = "https://cdn.discordapp.com/avatars/#{member.id}/#{member.avatar_id}.webp?size=1024"

  stars_given = database.get_total_stars_given server.id, member.id
  stars_received = database.get_total_stars_received server.id, member.id
  total_commands = database.get_total_command_count member.id
  server_commands = database.get_server_command_count member.id, server.id
  top_five_commands = database.get_top_five_favorite_command member.id

  top_five_value = array_to_discord_code_block top_five_commands
  top_five_value = '-' if top_five_commands.empty?

  Discordrb::Webhooks::Embed.new(
    color: 0x5cb200,
    author: Discordrb::Webhooks::EmbedAuthor.new(name: "#{member.username}:#{member.discriminator}", icon_url: avatar),
    fields: [
      Discordrb::Webhooks::EmbedField.new(name: 'Stars given:', value: stars_given, inline: true),
      Discordrb::Webhooks::EmbedField.new(name: 'Stars received:', value: stars_received, inline: true),
      Discordrb::Webhooks::EmbedField.new(name: 'Birthday:', value: '-', inline: true),
      Discordrb::Webhooks::EmbedField.new(name: 'Server commands:', value: server_commands, inline: true),
      Discordrb::Webhooks::EmbedField.new(name: 'Total commands:', value: total_commands, inline: true),
      Discordrb::Webhooks::EmbedField.new(name: 'Top 5 commands:', value: top_five_value, inline: false)
    ],
    image: Discordrb::Webhooks::EmbedImage.new(url: avatar)
  )
end

def create_embed_for_starboard_message(data)
  embed_image = Discordrb::Webhooks::EmbedImage.new(url: data['embed_image_url']) unless data['embed_image_url'].nil?
  fields = []
  fields = [Discordrb::Webhooks::EmbedField.new(name: 'Attachment:', value: data['attachment_link'])] unless data['attachment_link'].nil?

  Discordrb::Webhooks::Embed.new(
    color: 0x5cb200,
    description: data['content'],
    timestamp: Time.strptime(data['message_timestamp'], '%Y-%m-%d %H:%M:%S'),
    image: embed_image,
    author: Discordrb::Webhooks::EmbedAuthor.new(name: data['author_name'], icon_url: data['author_icon']),
    footer: Discordrb::Webhooks::EmbedFooter.new(text: "ID: #{data['message_id']}"),
    fields: fields
  )
end

def create_embed_for_top_starboard_messages(total_messages, total_reactions, top_star_messages, top_star_givers, top_star_receivers)
  top_messages = []
  top_star_messages.each do |m|
    url = create_message_link m['server_id'], m['channel_id'], m['message_id']
    top_messages.push "#{m['star_count']} ⭐: [#{m['message_id']}](#{url})"
  end

  top_givers = []
  top_star_givers.each do |g|
    top_givers.push "#{g['star_count']} ⭐: <@#{g['user_id']}>"
  end

  top_receivers = []
  top_star_receivers.each do |r|
    top_receivers.push "#{r['star_count']} ⭐: <@#{r['user_id']}>"
  end

  Discordrb::Webhooks::Embed.new(
    color: 0x5cb200,
    description: "#{total_messages} messages with a total of #{total_reactions} stars!",
    thumbnail: Discordrb::Webhooks::EmbedThumbnail.new(url: 'https://cdn.discordapp.com/attachments/1085306581534658572/1094217203689213962/stars.png'), # star png
    author: Discordrb::Webhooks::EmbedAuthor.new(name: 'Server Starboard'),
    fields: [
      Discordrb::Webhooks::EmbedField.new(name: 'Top messages:', value: top_messages.join("\n"), inline: false),
      Discordrb::Webhooks::EmbedField.new(name: 'Top givers:', value: top_givers.join("\n"), inline: true),
      Discordrb::Webhooks::EmbedField.new(name: 'Top receivers:', value: top_receivers.join("\n"), inline: true)
    ]
  )
end

def create_button_for_starboard_message(data)
  url = create_message_link data['server_id'], data['channel_id'], data['message_id']

  view = Discordrb::Webhooks::View.new
  view.row do |row|
    row.button(label: 'Original message', style: :link, url: url)
  end
  view
end

def create_top_five_buttons_for_starboard_message(data)
  return nil if data.empty?

  view = Discordrb::Webhooks::View.new
  view.row do |row|
    data.each do |d|
      star_count = d['star_count']
      url = create_message_link d['server_id'], d['channel_id'], d['message_id']
      row.button(label: "#{STAR} #{star_count}", style: :link, url: url)
    end
  end
  view
end

def create_message_link(server_id, channel_id, message_id)
  "https://discord.com/channels/#{server_id}/#{channel_id}/#{message_id}"
end
