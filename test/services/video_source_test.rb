require "test_helper"

class VideoSourceTest < ActiveSupport::TestCase
  YT = "https://www.youtube.com/watch?v=dQw4w9WgXcQ".freeze
  TT = "https://www.tiktok.com/@scout2015/video/6718335390845095173".freeze
  SHORT = "https://vt.tiktok.com/ZSXvNVQwY/".freeze

  test "routes each URL to its provider and claims nothing else" do
    assert_equal :youtube, VideoSource.provider(YT)
    assert_equal :youtube, VideoSource.provider("https://youtu.be/dQw4w9WgXcQ")
    assert_equal :tiktok, VideoSource.provider(TT)
    assert_equal :tiktok, VideoSource.provider(SHORT)
    assert_nil VideoSource.provider("https://vimeo.com/123456789")
    assert_nil VideoSource.provider(nil)
  end

  test "reads ids and canonical URLs through the right provider" do
    assert_equal "dQw4w9WgXcQ", VideoSource.video_id(YT)
    assert_equal "6718335390845095173", VideoSource.video_id(TT)
    assert_equal YT, VideoSource.canonical("https://youtu.be/dQw4w9WgXcQ?t=9")
    assert_equal TT, VideoSource.canonical("#{TT}?is_from_webapp=1")
  end

  # The distinction the Add Video sheet depends on. Asking for an id would
  # reject the single most common thing a user pastes for TikTok.
  test "a share link is importable even though it has no id yet" do
    assert_nil VideoSource.video_id(SHORT)
    assert VideoSource.importable?(SHORT)
  end

  test "importable? accepts a bare YouTube id but not a search phrase" do
    assert VideoSource.importable?("dQw4w9WgXcQ")
    assert_not VideoSource.importable?("easy spanish interviews")
    assert_not VideoSource.importable?("https://vimeo.com/123456789")
    assert_not VideoSource.importable?("")
  end

  # Why courses.thumbnail_url exists: YouTube covers come from a public static
  # pattern, TikTok's are signed CDN URLs that only oEmbed knows.
  test "only YouTube covers are derivable from the URL" do
    assert_equal "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
                 VideoSource.derived_thumbnail_url(YT)
    assert_nil VideoSource.derived_thumbnail_url(TT)
    assert_nil VideoSource.derived_thumbnail_url("https://vimeo.com/1")
  end

  test "an unsupported URL is refused before any network call" do
    assert_raises(VideoSource::UnavailableVideo) do
      VideoSource.fetch("https://vimeo.com/123456789")
    end
  end

  # Written before TikTok existed and referenced from rescue clauses across the
  # app; if this alias breaks, imports fail instead of showing "video is private".
  test "the legacy Youtube::Oembed error name still catches provider failures" do
    assert_raises(Youtube::Oembed::UnavailableVideo) do
      VideoSource.fetch("not a link at all")
    end
  end

  # This runs after the credit has been spent, so a weak title must beat a
  # raised exception.
  test "fetch_title degrades instead of failing an import that was paid for" do
    assert VideoSource.fetch_title("https://vimeo.com/1").present?
    assert_equal "My Clip", VideoSource.fetch_title("https://vimeo.com/1", fallback: "My Clip")
  end
end

class TiktokOembedTest < ActiveSupport::TestCase
  SHORT = "https://vt.tiktok.com/ZSXvNVQwY/".freeze

  RESPONSE = {
    "title" => "Scout & Suki",
    "author_name" => "Scout & Suki",
    "author_unique_id" => "scout2015",
    "embed_product_id" => "6718335390845095173",
    "thumbnail_url" => "https://p16-sign-va.tiktokcdn.com/obj/abc~tplv.jpeg?x-expires=1&x-signature=z"
  }.to_json

  # The job only oEmbed can do: TikTok follows the redirect server-side and
  # hands back the numeric post id, so a share link only becomes importable here.
  test "resolves a share link into a post id and a canonical URL" do
    video = Tiktok::Oembed.stub(:http_get, ->(_uri) { RESPONSE }) do
      Tiktok::Oembed.fetch(SHORT)
    end

    assert_equal :tiktok, video.provider
    assert video.tiktok?
    assert_equal "6718335390845095173", video.video_id
    assert_equal "https://www.tiktok.com/@scout2015/video/6718335390845095173", video.canonical_url
  end

  # The only place a TikTok cover exists; Imports::Create stores it because it
  # cannot be derived later.
  test "returns the signed cover URL" do
    video = Tiktok::Oembed.stub(:http_get, ->(_uri) { RESPONSE }) do
      Tiktok::Oembed.fetch(SHORT)
    end

    assert_match %r{tiktokcdn\.com}, video.thumbnail_url
    assert_nil VideoSource.derived_thumbnail_url(video.canonical_url),
               "a stored cover is the only way TikTok gets one"
  end

  test "refuses a URL that isn't TikTok's before making a request" do
    assert_raises(VideoSource::UnavailableVideo) do
      Tiktok::Oembed.fetch("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    end
  end

  test "a response without a post id is treated as an unavailable video" do
    assert_raises(VideoSource::UnavailableVideo) do
      Tiktok::Oembed.stub(:http_get, ->(_uri) { "{}" }) { Tiktok::Oembed.fetch(SHORT) }
    end
  end
end
