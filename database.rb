# frozen_string_literal: true

require 'sqlite3'

class Database
  def initialize(filename)
    @db = SQLite3::Database.new filename, results_as_hash: true
    create_versions_table_if_needed
  end

  def migrate(directory_path)
    directory = Pathname.new directory_path
    files = Dir.glob '*.sql', base: directory_path

    file_map = {}
    files.each do |file|
      number = file.split('_').first.to_i
      file_map[number] = file
    end

    file_map.sort.each do |version_number, file_name|
      if version_exist? version_number
        puts "Skip version: #{version_number}"
        next
      end

      full_file_path = directory.join file_name
      file = File.open full_file_path
      file_data = file.read

      begin
        @db.transaction
        @db.execute_batch file_data
        @db.commit
      rescue SQLite3::Exception => e
        puts "Transaction failed: #{e}"
        break
      end

      insert_version version_number
    end
  end

  def execute(sql)
    @db.execute sql
  end

  def set_server_chat_context(server_id, context)
    @db.execute 'INSERT OR REPLACE INTO chat_context (server_id, text) VALUES (?, ?)', [server_id, context]
  end

  def get_server_chat_context(server_id)
    result = @db.execute 'SELECT text FROM chat_context WHERE server_id = ?', [server_id]
    return nil if result.empty?

    result[0]['text']
  end

  def insert_command_usage(user_id, server_id, command_name, command)
    insert_command_sql = <<-SQL
    INSERT INTO command_usage (user_id, server_id, command_name, command)
    VALUES(?, ?, ?, ?)
    SQL

    @db.execute insert_command_sql, [user_id, server_id, command_name, command]
  end

  def get_server_command_count(user_id, server_id)
    result = @db.execute 'SELECT count(1) FROM command_usage WHERE user_id = ? AND server_id = ?', [user_id, server_id]
    return 0 if result.empty?

    result[0]['count(1)']
  end

  def get_total_command_count(user_id)
    result = @db.execute 'SELECT count(1) FROM command_usage WHERE user_id = ?', [user_id]
    return 0 if result.empty?

    result[0]['count(1)']
  end

  def get_top_five_favorite_command(user_id)
    favorite_command_sql = <<-SQL
    SELECT command_name, count(1) AS count
    FROM command_usage
    WHERE user_id = ?
    GROUP BY command_name
    ORDER BY count DESC LIMIT 5
    SQL

    @db.execute favorite_command_sql, [user_id]
  end

  def insert_starboard(
    star_count,
    message_id,
    channel_id,
    server_id,
    starboard_message_id,
    content,
    message_timestamp,
    author_name,
    author_icon,
    embed_image_url,
    jump_link,
    attachment_link
  )

    insert_command_sql = <<-SQL
    INSERT OR REPLACE INTO starboard (
    star_count,
    message_id,
    channel_id,
    server_id,
    starboard_message_id,
    content,
    message_timestamp,
    author_name,
    author_icon,
    embed_image_url,
    jump_link,
    attachment_link)
    VALUES(?, ?, ?, ?, ?, ?, datetime(?), ?, ?, ?, ?, ?)
    SQL

    @db.execute insert_command_sql, [
      star_count,
      message_id,
      channel_id,
      server_id,
      starboard_message_id,
      content,
      message_timestamp.strftime('%Y-%m-%d %H:%M:%S'),
      author_name,
      author_icon,
      embed_image_url,
      jump_link,
      attachment_link
    ]
  end

  private

  def create_versions_table_if_needed
    create_versions_sql = <<-SQL
    CREATE TABLE IF NOT EXISTS versions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      version INTEGER,
      date TEXT);
    SQL

    @db.execute create_versions_sql
  end

  def insert_version(number)
    @db.execute "INSERT INTO versions (version, date) VALUES (?, datetime('now'))", [number]
  end

  def version_exist?(number)
    result = @db.execute 'SELECT 1 FROM versions where version = ?', [number]
    !result.empty?
  end
end
