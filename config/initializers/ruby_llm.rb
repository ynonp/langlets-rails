RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.dig(:openai_api_key)
  config.anthropic_api_key = Rails.application.credentials.dig(:anthropic_api_key)
  config.gemini_api_key = Rails.application.credentials.dig(:google_api_key)
  config.deepseek_api_key = Rails.application.credentials.dig(:deepseek_api_key)
  config.openrouter_api_key = Rails.application.credentials.dig(:openrouter_api_key)
  config.request_timeout = 600
end

