require "test_helper"

module Youtube
  class UrlTest < ActiveSupport::TestCase
    VIDEO_ID = "kJQP7kiw5Fk".freeze

    test "extracts the video id from every URL shape we accept" do
      {
        "https://www.youtube.com/watch?v=#{VIDEO_ID}"          => "plain watch",
        "https://youtube.com/watch?v=#{VIDEO_ID}"              => "no www",
        "http://www.youtube.com/watch?v=#{VIDEO_ID}"           => "http",
        "https://youtu.be/#{VIDEO_ID}"                         => "short link",
        "https://www.youtube.com/shorts/#{VIDEO_ID}"           => "shorts",
        "https://www.youtube.com/embed/#{VIDEO_ID}"            => "embed",
        "https://www.youtube.com/watch?v=#{VIDEO_ID}&t=42س"    => "trailing params",
        "https://www.youtube.com/watch?feature=share&v=#{VIDEO_ID}" => "params before v",
        "https://m.youtube.com/watch?v=#{VIDEO_ID}"            => "mobile host"
      }.each do |url, description|
        assert_equal VIDEO_ID, Url.video_id(url), "failed for #{description}: #{url}"
      end
    end

    test "returns nil for things that aren't YouTube videos" do
      [ nil, "", "   ", "not a url", "https://vimeo.com/12345",
        "https://www.youtube.com/watch?v=tooshort" ].each do |url|
        assert_nil Url.video_id(url), "expected nil for #{url.inspect}"
      end
    end

    # Dedupe compares stored URLs, so youtu.be/X and watch?v=X&t=9 have to reduce
    # to the same string or the same video imports twice.
    test "canonical collapses every spelling of a video to one URL" do
      expected = "https://www.youtube.com/watch?v=#{VIDEO_ID}"

      assert_equal expected, Url.canonical("https://youtu.be/#{VIDEO_ID}")
      assert_equal expected, Url.canonical("https://www.youtube.com/watch?v=#{VIDEO_ID}&t=90")
      assert_equal expected, Url.canonical("https://www.youtube.com/shorts/#{VIDEO_ID}")
      assert_equal expected, Url.canonical(expected)
    end

    test "canonical returns nil when there's no video" do
      assert_nil Url.canonical("https://example.com")
    end

    test "valid? reports whether a URL names a video" do
      assert Url.valid?("https://youtu.be/#{VIDEO_ID}")
      assert_not Url.valid?("https://example.com")
      assert_not Url.valid?(nil)
    end
  end
end
