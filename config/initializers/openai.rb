OpenAI.configure do |config|
  config.access_token = Rails.application.credentials.dig(:openai, :access_token) || ENV["OPENAI_ACCESS_TOKEN"]
end