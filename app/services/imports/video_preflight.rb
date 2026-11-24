require "net/http"
require "json"

module Imports
  # The synchronous, read-only gate shared by every user-facing import entry
  # point. oEmbed proves the provider can see the video; Supadata metadata adds
  # duration before Rails writes an import-related record.
  #
  # Duration metadata is deliberately best-effort. If the metadata service is
  # temporarily unavailable, the pipeline's own guard checks again immediately
  # before expensive work. A known over-limit video, however, never gets a
  # request, course, signup placeholder, or credit reservation.
  class VideoPreflight
    ENDPOINT = "https://api.supadata.ai/v1/metadata".freeze
    MAXIMUM_DURATION_SECONDS = 25.minutes.to_i
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    class TooLong < StandardError
      attr_reader :maximum_minutes

      def initialize(maximum_seconds)
        @maximum_minutes = maximum_seconds.to_f.fdiv(60).floor
        super("video exceeds the #{maximum_minutes}-minute limit")
      end
    end

    Result = Data.define(:video, :duration_seconds, :maximum_duration_seconds)

    def self.call(url)
      video = VideoSource.fetch(url)
      details = details_for(video)
      duration = details&.fetch(:duration)
      if video.tiktok? && video.thumbnail_url.blank? && details&.fetch(:thumbnail_url)
        video = video.with(thumbnail_url: details.fetch(:thumbnail_url))
      end

      raise TooLong, MAXIMUM_DURATION_SECONDS if duration && duration > MAXIMUM_DURATION_SECONDS

      Result.new(
        video:,
        duration_seconds: duration,
        maximum_duration_seconds: MAXIMUM_DURATION_SECONDS
      )
    end

    # Also used by the background refresh when TikTok oEmbed omits a cover.
    def self.tiktok_thumbnail_for(video)
      details_for(video)&.fetch(:thumbnail_url)
    end

    def self.details_for(video)
      Rails.cache.fetch(
        [ "imports-video-details", video.provider, video.video_id ],
        expires_in: 15.minutes,
        skip_nil: true
      ) do
        metadata = fetch_metadata(video.canonical_url)
        duration = positive_number(metadata["duration"] || metadata.dig("media", "duration"))
        thumbnail_url = tiktok_thumbnail(metadata, video)
        { duration:, thumbnail_url: } if duration || thumbnail_url
      end
    rescue StandardError => error
      Rails.logger.warn "Video metadata lookup failed for #{video.canonical_url.inspect}: #{error.message}"
      nil
    end

    def self.fetch_metadata(video_url)
      uri = URI(ENDPOINT)
      uri.query = URI.encode_www_form(url: video_url)
      JSON.parse(http_get(uri, api_key))
    end

    def self.tiktok_thumbnail(metadata, video)
      return unless video.tiktok? && metadata["platform"] == "tiktok" && metadata["id"].to_s == video.video_id.to_s

      candidate = URI.parse(metadata.dig("media", "thumbnailUrl").to_s)
      candidate.to_s if candidate.is_a?(URI::HTTPS) && candidate.host.present?
    rescue URI::InvalidURIError
      nil
    end

    def self.http_get(uri, key)
      request = Net::HTTP::Get.new(uri)
      request["x-api-key"] = key
      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      ) do |http|
        # Net::HTTP retries idempotent requests once by default, which could
        # turn this best-effort preflight into a roughly 30-second page load.
        http.max_retries = 0
        http.request(request)
      end
      raise "Supadata metadata request failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end

    def self.api_key
      ENV["SUPADATA_KEY"].presence ||
        ENV["SUPADATA_API_KEY"].presence ||
        Rails.application.credentials.dig(:supadata_key).presence ||
        raise("Supadata key is missing")
    end

    def self.positive_number(value)
      number = Float(value, exception: false)
      number if number&.positive? && number.finite?
    end
    private_class_method :details_for, :fetch_metadata, :tiktok_thumbnail, :http_get, :api_key, :positive_number
  end
end
