RubyLLM.configure do |config|
  config.anthropic_api_key = Rails.application.credentials.dig(:anthropic_api_key)
  config.gemini_api_key = Rails.application.credentials.dig(:google_api_key)
  config.openrouter_api_key = Rails.application.credentials.dig(:openrouter_api_key)
  config.deepseek_api_key = Rails.application.credentials.dig(:deepseek_api_key)
  config.request_timeout = 600

  # use ollama cloud endpoint
  config.ollama_api_key = Rails.application.credentials.dig(:ollama_api_key)
  config.ollama_api_base = "https://ollama.com/v1"
end

