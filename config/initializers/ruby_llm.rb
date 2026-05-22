RubyLLM.configure do |config|
  config.anthropic_api_key = Rails.application.credentials.dig(:anthropic_api_key)
  config.gemini_api_key = Rails.application.credentials.dig(:google_api_key)
  config.openrouter_api_key = Rails.application.credentials.dig(:openrouter_api_key)
  config.deepseek_api_key = Rails.application.credentials.dig(:deepseek_api_key)
  config.request_timeout = 600

  # use ollama cloud endpoint
  config.openai_api_key = Rails.application.credentials.dig(:ollama_api_key)
  config.openai_api_base = "http://localhost:11434/v1" # Your endpoint
  config.openai_use_system_role = true
end

