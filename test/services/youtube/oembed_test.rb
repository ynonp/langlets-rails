require "test_helper"
require "minitest/mock"

module Youtube
  class OembedTest < ActiveSupport::TestCase
    VIDEO_ID = "kJQP7kiw5Fk".freeze
    URL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

    BODY = {
      title: "Valentina y el Dragón — Cuento Completo",
      author_name: "Cuentos Infantiles",
      thumbnail_url: "https://i.ytimg.com/vi/#{VIDEO_ID}/hqdefault.jpg"
    }.to_json.freeze

    test "returns the video's metadata" do
      video = with_response(BODY) { Oembed.fetch("https://youtu.be/#{VIDEO_ID}") }

      assert_equal VIDEO_ID, video.video_id
      assert_equal "Valentina y el Dragón — Cuento Completo", video.title
      assert_equal "Cuentos Infantiles", video.author_name
      assert_equal URL, video.canonical_url, "the URL should be canonicalised before use"
    end

    test "rejects a URL that isn't a YouTube video without calling out" do
      Oembed.stub(:http_get, ->(_uri) { flunk "should not have made a request" }) do
        assert_raises(Oembed::UnavailableVideo) { Oembed.fetch("https://example.com") }
      end
    end

    # This is how the Add screen refuses a private/deleted video before a credit
    # is ever spent.
    test "raises UnavailableVideo when YouTube won't describe the video" do
      Oembed.stub(:http_get, ->(_uri) { raise Oembed::UnavailableVideo, "video is private" }) do
        assert_raises(Oembed::UnavailableVideo) { Oembed.fetch(URL) }
      end
    end

    test "raises UnavailableVideo on a non-JSON response" do
      error = assert_raises(Oembed::UnavailableVideo) do
        with_response("<html>nope</html>") { Oembed.fetch(URL) }
      end

      assert_match(/isn't JSON/, error.message)
    end

    test "falls back to a blank title rather than nil" do
      video = with_response({ author_name: "x" }.to_json) { Oembed.fetch(URL) }

      assert_equal "Untitled Course", video.title
    end

    # Background paths have already charged the user, so a weak title beats a
    # failed import.
    test "fetch_title degrades to the video id instead of raising" do
      Oembed.stub(:http_get, ->(_uri) { raise Oembed::UnavailableVideo, "boom" }) do
        assert_equal VIDEO_ID, Oembed.fetch_title(URL)
      end
    end

    test "fetch_title uses an explicit fallback when given one" do
      Oembed.stub(:http_get, ->(_uri) { raise Oembed::UnavailableVideo, "boom" }) do
        assert_equal "My Course", Oembed.fetch_title(URL, fallback: "My Course")
      end
    end

    test "requests the oEmbed endpoint with the canonical url" do
      requested = nil
      Oembed.stub(:http_get, ->(uri) { requested = uri; BODY }) do
        Oembed.fetch("https://youtu.be/#{VIDEO_ID}")
      end

      assert_equal "www.youtube.com", requested.host
      assert_equal "/oembed", requested.path
      assert_includes requested.query, "format=json"
      assert_includes CGI.unescape(requested.query), URL
    end

    private

    def with_response(body, &block)
      Oembed.stub(:http_get, ->(_uri) { body }, &block)
    end
  end
end
