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
