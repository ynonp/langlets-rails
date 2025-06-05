class LyricsScraperService
  # --- Custom Error Classes ---
  # A base error class that other service-specific errors can inherit from.
  # This allows a caller to rescue any error from this service with `rescue LyricsScraperService::Error`.
  class Error < StandardError; end

  # Specific error classes for different failure scenarios.
  class InvalidURLError < Error; end
  class NetworkError < Error; end
  class ParsingError < Error; end # For both HTML and JSON issues
  class ContentNotFoundError < Error; end

  # A convenience class method to allow calling the service with `LyricsScraperService.call(url)`
  def self.call(url)
    new(url).call
  end

  def initialize(raw_url)
    @raw_url = raw_url
  end

  # The main public method that performs the work.
  # On success, it returns the lyrics string.
  # On failure, it raises one of the custom exceptions.
  def call
    raise InvalidURLError, "URL cannot be blank." if @raw_url.blank?

    encoded_url = normalize_url(@raw_url)
    html_content = fetch_html(encoded_url)
    doc = parse_html(html_content)
    json_string = extract_json_from_doc(doc)
    lyrics = extract_lyrics_from_json(json_string)

    lyrics # Return the final lyrics string on success
  end

  private

  def normalize_url(url_string)
    Addressable::URI.parse(url_string).normalize.to_s
  rescue Addressable::URI::InvalidURIError
    raise InvalidURLError, "The provided URL is malformed."
  end

  def headers
    {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36"
    }
  end

  def fetch_html(url)
    response = HTTParty.get(url, headers: headers)
    raise NetworkError, "Failed to fetch URL. Status: #{response.code}" unless response.success?
    response.body
  rescue StandardError => e
    # Re-raise standard network errors (e.g. timeout, DNS error) as our custom error
    raise NetworkError, e.message
  end

  def parse_html(html_content)
    Nokogiri::HTML(html_content)
  end

  def extract_json_from_doc(doc)
    script_tag = doc.at_css('script#__NEXT_DATA__')
    raise ContentNotFoundError, "Could not find the lyrics JSON data script on the page." unless script_tag
    script_tag.content
  end

  def extract_lyrics_from_json(json_string)
    parsed_json = JSON.parse(json_string)
    lyrics = parsed_json.dig('props', 'pageProps', 'data', 'trackInfo', 'data', 'lyrics', 'body')
    raise ContentNotFoundError, "Could not find the lyrics within the page's JSON data." unless lyrics
    lyrics
  end
end