require "net/http"
require "json"

module Youtube
  # Fetches a video's public metadata from YouTube's oEmbed endpoint. No API key
  # and no quota, which is why it's preferred over the Data API here.
  #
  # It also doubles as an availability check: oEmbed answers 401/403 for private
  # videos and 404 for deleted ones. That's how the Add screen rejects a bad URL
  # *before* charging a credit.
  #
  # It does NOT return duration or age-restriction — those need Data API v3.
  class Oembed
    # Both now live in VideoSource so every provider raises and returns the same
    # things. Kept as aliases because these two names are referenced from rescue
    # clauses and test fixtures across the app, and a rescue that stopped
    # catching would fail an import instead of showing "video is private".
    UnavailableVideo = VideoSource::UnavailableVideo
    Video = VideoSource::Video

    ENDPOINT = "https://www.youtube.com/oembed".freeze
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 5

    class << self
      # Raises UnavailableVideo for anything we can't turn into a course.
      def fetch(url)
        canonical = Url.canonical(url)
        raise UnavailableVideo, "not a YouTube URL: #{url.inspect}" if canonical.blank?

        body = http_get(endpoint_for(canonical))
        parse(body, canonical)
      end

      # Best-effort variant for background paths that would rather use a weak
      # title than fail an import that has already been paid for.
      def fetch_title(url, fallback: nil)
        fetch(url).title
      rescue UnavailableVideo, StandardError => e
        Rails.logger.warn "oEmbed title lookup failed for #{url.inspect}: #{e.message}"
        fallback || Url.video_id(url) || "Untitled Course"
      end

      # Seam for tests — stubbed rather than pulling in webmock.
      def http_get(uri)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                   open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.request(Net::HTTP::Get.new(uri))
        end

        case response
        when Net::HTTPSuccess
          response.body
        when Net::HTTPUnauthorized, Net::HTTPForbidden
          raise UnavailableVideo, "video is private"
        when Net::HTTPNotFound
          raise UnavailableVideo, "video does not exist"
        else
          raise UnavailableVideo, "YouTube returned #{response.code}"
        end
      rescue Timeout::Error, Errno::ECONNRESET, SocketError => e
        raise UnavailableVideo, "could not reach YouTube: #{e.message}"
      end

      private

      def endpoint_for(canonical_url)
        URI("#{ENDPOINT}?#{URI.encode_www_form(url: canonical_url, format: 'json')}")
      end

      def parse(body, canonical_url)
        data = JSON.parse(body)

        Video.new(
          provider: :youtube,
          video_id: Url.video_id(canonical_url),
          title: data["title"].presence || "Untitled Course",
          author_name: data["author_name"],
          thumbnail_url: data["thumbnail_url"],
          canonical_url: canonical_url
        )
      rescue JSON::ParserError => e
        raise UnavailableVideo, "YouTube returned something that isn't JSON: #{e.message}"
      end
    end
  end
end
