
require 'langchain/llm/google_gemini'

# This module adds a dedicated `read_timeout` attribute to the class.
module GoogleGeminiTimeoutAttribute
  # This one line creates two methods for us:
  # 1. `read_timeout` (the getter, to read the value)
  # 2. `read_timeout=` (the setter, to assign the value)
  # It manages the underlying instance variable `@read_timeout`.
  attr_accessor :read_timeout

  # We still patch http_post to use the value from our new attribute.
  def http_post(url, params)
    http = Net::HTTP.new(url.hostname, url.port)
    http.use_ssl = url.scheme == "https"
    http.set_debug_output(Langchain.logger) if Langchain.logger.debug?
    http.read_timeout = @read_timeout if @read_timeout

    request = Net::HTTP::Post.new(url)
    request.content_type = "application/json"
    request.body = params.to_json

    response = http.request(request)

    JSON.parse(response.body)
  end
end

Langchain::LLM::GoogleGemini.prepend(GoogleGeminiTimeoutAttribute)
