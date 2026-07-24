require "net/http"
require "json"

module Tiktok
  # TikTok's public oEmbed endpoint. No API key and no quota, same as YouTube's.
  #
  # It does three jobs here, and only the first is obvious:
  #
  # 1. Availability check — 400/403/404 for a private, deleted or region-blocked
  #    post, which is how the Add screen rejects a bad link *before* a credit
  #    moves.
  # 2. Short-link resolution — TikTok follows vt.tiktok.com/... server-side and
  #    hands back embed_product_id, the numeric post id. Nothing else can do
  #    this, so a share-sheet link only becomes importable through here.
  # 3. Cover image — TikTok thumbnails are signed CDN URLs with an expiry, so
  #    unlike YouTube they cannot be derived from the id. This is the only
  #    source, which is why Imports::Create stores it on courses.thumbnail_url.
  class Oembed
    UnavailableVideo = VideoSource::UnavailableVideo

    ENDPOINT = "https://www.tiktok.com/oembed".freeze
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 5

    class << self
      def fetch(url)
        raise UnavailableVideo, "not a TikTok URL: #{url.inspect}" unless Url.match?(url)

        body = http_get(endpoint_for(url))
        parse(body, url)
      end

      def fetch_title(url, fallback: nil)
        fetch(url).title
      rescue UnavailableVideo, StandardError => e
        Rails.logger.warn "TikTok oEmbed title lookup failed for #{url.inspect}: #{e.message}"
        fallback || Url.video_id(url) || "Untitled Course"
      end

      # Seam for tests — stubbed rather than pulling in webmock, matching
      # Youtube::Oembed.
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
        when Net::HTTPNotFound, Net::HTTPBadRequest
          # TikTok answers 400 rather than 404 for a post that no longer exists.
          raise UnavailableVideo, "video does not exist"
        else
          raise UnavailableVideo, "TikTok returned #{response.code}"
        end
      rescue Timeout::Error, Errno::ECONNRESET, SocketError => e
        raise UnavailableVideo, "could not reach TikTok: #{e.message}"
      end

      private

      def endpoint_for(url)
        URI("#{ENDPOINT}?#{URI.encode_www_form(url: url)}")
      end

      def parse(body, requested_url)
        data = JSON.parse(body)

        # embed_product_id is the numeric post id even when we asked with a short
        # link, which is the whole point of routing short links through here.
        video_id = data["embed_product_id"].presence || Url.video_id(requested_url)
        raise UnavailableVideo, "TikTok did not return a post id for #{requested_url.inspect}" if video_id.blank?

        handle = data["author_unique_id"].presence || Url.author_handle(requested_url)

        VideoSource::Video.new(
          provider: :tiktok,
          video_id: video_id,
          title: data["title"].presence || "Untitled Course",
          author_name: data["author_name"].presence || handle,
          thumbnail_url: data["thumbnail_url"].presence,
          canonical_url: Url.canonical_for(video_id, handle)
        )
      rescue JSON::ParserError => e
        raise UnavailableVideo, "TikTok returned something that isn't JSON: #{e.message}"
      end
    end
  end
end
