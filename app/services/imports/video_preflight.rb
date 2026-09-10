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
    MAXIMUM_DURATION_SECONDS = 20.minutes.to_i
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
      duration = duration_for(video)

      raise TooLong, MAXIMUM_DURATION_SECONDS if duration && duration > MAXIMUM_DURATION_SECONDS

      Result.new(
        video:,
        duration_seconds: duration,
        maximum_duration_seconds: MAXIMUM_DURATION_SECONDS
      )
    end

    def self.duration_for(video)
      Rails.cache.fetch(
        [ "imports-video-preflight", video.provider, video.video_id ],
        expires_in: 15.minutes,
        skip_nil: true
      ) { fetch_duration(video.canonical_url) }
    rescue StandardError => error
      Rails.logger.warn "Video duration preflight failed for #{video.canonical_url.inspect}: #{error.message}"
      nil
    end
    private_class_method :duration_for

    def self.fetch_duration(video_url)
      uri = URI(ENDPOINT)
      uri.query = URI.encode_www_form(url: video_url)
      metadata = JSON.parse(http_get(uri, api_key))
      duration = positive_number(metadata["duration"] || metadata.dig("media", "duration"))
      raise "Supadata returned a missing or invalid duration" unless duration

      duration
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
    private_class_method :fetch_duration, :http_get, :api_key, :positive_number
  end
end
