require "test_helper"

module Imports
  class VideoPreflightTest < ActiveSupport::TestCase
    URL = "https://www.youtube.com/watch?v=kJQP7kiw5Fk".freeze

    setup do
      @video = VideoSource::Video.new(
        video_id: "kJQP7kiw5Fk",
        title: "Example",
        author_name: "Teacher",
        thumbnail_url: "https://example.com/thumb.jpg",
        canonical_url: URL
      )
    end

    test "returns provider metadata for a video within the limit" do
      result = with_duration(1199) do
        VideoPreflight.call(URL)
      end

      assert_equal @video, result.video
      assert_equal 1199, result.duration_seconds
      assert_equal 1200, result.maximum_duration_seconds
    end

    test "accepts a video exactly at the limit" do
      assert_nothing_raised do
        with_duration(1200) do
          VideoPreflight.call(URL)
        end
      end
    end

    test "rejects a known over-limit video before import records are written" do
      error = assert_raises(VideoPreflight::TooLong) do
        with_duration(1201) do
          VideoPreflight.call(URL)
        end
      end

      assert_equal 20, error.maximum_minutes
      assert_equal 0, ImportRequest.count
    end

    test "keeps the provider availability result when duration lookup is unavailable" do
      result = VideoSource.stub(:fetch, @video) do
        VideoPreflight.stub(:fetch_duration, ->(_url) { raise Net::ReadTimeout, "offline" }) do
          VideoPreflight.call(URL)
        end
      end

      assert_equal @video, result.video
      assert_nil result.duration_seconds
      assert_equal 1200, result.maximum_duration_seconds
    end

    test "does not cache a failed duration lookup" do
      cache = ActiveSupport::Cache::MemoryStore.new
      attempts = 0

      Rails.stub(:cache, cache) do
        VideoSource.stub(:fetch, @video) do
          VideoPreflight.stub(:fetch_duration, lambda { |_url|
            attempts += 1
            raise Net::ReadTimeout, "offline" if attempts == 1

            90
          }) do
            assert_nil VideoPreflight.call(URL).duration_seconds
            assert_equal 90, VideoPreflight.call(URL).duration_seconds
          end
        end
      end

      assert_equal 2, attempts
    end

    test "reads current and legacy Supadata duration responses" do
      [ [ { duration: 90 }, 90 ], [ { media: { duration: 91 } }, 91 ] ].each do |body, expected|
        VideoPreflight.stub(:api_key, "test-key") do
          VideoPreflight.stub(:http_get, ->(_uri, _key) { body.to_json }) do
            assert_equal expected, VideoPreflight.send(:fetch_duration, URL)
          end
        end
      end
    end

    test "sends the canonical URL and API key to Supadata" do
      requested_uri = nil
      requested_key = nil
      old_key = ENV["SUPADATA_KEY"]
      ENV["SUPADATA_KEY"] = "test-key"

      VideoPreflight.stub(:http_get, lambda { |uri, key|
        requested_uri = uri
        requested_key = key
        { duration: 90 }.to_json
      }) do
        VideoPreflight.send(:fetch_duration, URL)
      end

      assert_equal "api.supadata.ai", requested_uri.host
      assert_equal "/v1/metadata", requested_uri.path
      assert_equal URL, CGI.parse(requested_uri.query).fetch("url").first
      assert_equal "test-key", requested_key
    ensure
      ENV["SUPADATA_KEY"] = old_key
    end

    test "accepts the standard Supadata environment variable as a fallback" do
      old_key = ENV["SUPADATA_KEY"]
      old_api_key = ENV["SUPADATA_API_KEY"]
      ENV.delete("SUPADATA_KEY")
      ENV["SUPADATA_API_KEY"] = "fallback-key"

      assert_equal "fallback-key", VideoPreflight.send(:api_key)
    ensure
      ENV["SUPADATA_KEY"] = old_key
      ENV["SUPADATA_API_KEY"] = old_api_key
    end

    private

    def with_duration(duration, &block)
      VideoSource.stub(:fetch, @video) do
        VideoPreflight.stub(:fetch_duration, duration, &block)
      end
    end
  end
end
