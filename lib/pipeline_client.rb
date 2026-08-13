require "net/http"

class PipelineClient
  class Error < StandardError; end
  class ConfigurationError < Error; end

  TRIGGER_READ_TIMEOUT = 30
  READ_TIMEOUT = Integer(ENV.fetch("PIPELINE_READ_TIMEOUT", 3_000))
  OPEN_TIMEOUT = 15

  class << self
    def detect_language(payload)
      post("/detect-language", payload, read_timeout: READ_TIMEOUT)
    end

    def run(payload, wait: false)
      path = wait ? "/run" : "/run?async=1"
      post(path, payload, read_timeout: wait ? READ_TIMEOUT : TRIGGER_READ_TIMEOUT)
    end

    def base_url
      url = Rails.configuration.x.pipeline.url.presence
      raise ConfigurationError, "PIPELINE_URL is not configured; the AI pipeline runs out of process" if url.nil?

      url.delete_suffix("/")
    end

    private

    def post(path, payload, read_timeout:)
      raise ConfigurationError, "PIPELINE_HMAC_SECRET is not configured" if PipelineHmac.secret.blank?

      body = payload.to_json
      uri = URI.parse("#{base_url}#{path}")
      request = Net::HTTP::Post.new(uri)
      PipelineHmac.signed_headers(body).each { |name, value| request[name] = value }
      request.body = body

      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: OPEN_TIMEOUT,
        read_timeout:
      ) { |http| http.request(request) }

      parse_response(response)
    rescue Net::OpenTimeout, Net::ReadTimeout, SystemCallError, SocketError, OpenSSL::SSL::SSLError => error
      raise Error, "could not reach the pipeline at #{base_url}: #{error.message}"
    end

    def parse_response(response)
      if response.code.to_i.between?(200, 299)
        return JSON.parse(response.body.to_s)
      end

      parsed = JSON.parse(response.body.to_s)
      message = parsed["error"].presence || response.body.to_s.truncate(500)
      raise Error, "pipeline #{base_url} returned #{response.code}: #{message}"
    rescue JSON::ParserError => error
      unless response.code.to_i.between?(200, 299)
        raise Error, "pipeline #{base_url} returned #{response.code}: #{response.body.to_s.truncate(500)}"
      end

      raise Error, "pipeline returned an unreadable response: #{error.message}"
    end
  end
end
