# frozen_string_literal: true

require 'net/http'
require 'json'

def ask_chat_gpt(messages, config)
  chat_gpt_url = URI('https://api.openai.com/v1/chat/completions')
  query_body = { model: 'gpt-3.5-turbo', messages: messages }
  chat_gpt_header = { 'Content-Type': 'application/json', 'Authorization': "Bearer #{config.chatgpt_token}" }

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
