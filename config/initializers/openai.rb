OpenAI.configure do |config|
  config.access_token = Rails.application.credentials.dig(:openai_key)  
  config.log_errors = true
end
