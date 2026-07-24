require "test_helper"

class TiktokUrlTest < ActiveSupport::TestCase
  POST = "https://www.tiktok.com/@scout2015/video/6718335390845095173".freeze
  VIDEO_ID = "6718335390845095173".freeze

  test "reads the post id from every URL form that carries one" do
    [
      POST,
      "https://www.tiktok.com/@scout2015/photo/#{VIDEO_ID}",
      "https://www.tiktok.com/embed/v2/#{VIDEO_ID}",
      "https://www.tiktok.com/player/v1/#{VIDEO_ID}",
      "https://m.tiktok.com/v/#{VIDEO_ID}.html",
      "#{POST}?is_from_webapp=1&sender_device=pc"
    ].each do |url|
      assert_equal VIDEO_ID, Tiktok::Url.video_id(url), url
    end
  end

  # The asymmetry with YouTube that shapes the whole design: we can tell it's a
  # TikTok link without being able to say which post it is.
  test "a share link is recognized but has no id until oEmbed resolves it" do
    short = "https://vt.tiktok.com/ZSXvNVQwY/"

    assert Tiktok::Url.match?(short)
    assert_nil Tiktok::Url.video_id(short)
    assert_equal "ZSXvNVQwY", Tiktok::Url.short_code(short)
  end

  test "recognizes every share-link host" do
    [
      "https://vt.tiktok.com/ZSXvNVQwY/",
      "https://vm.tiktok.com/ZMabcdefg/",
      "https://www.tiktok.com/t/ZTabcdefg/"
    ].each { |url| assert Tiktok::Url.match?(url), url }
  end

  test "does not claim URLs belonging to other providers" do
    [
      "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      "https://vimeo.com/123456789",
      "https://nottiktok.com/@a/video/123456789012",
      "easy spanish interviews",
      nil,
      ""
    ].each { |url| assert_not Tiktok::Url.match?(url), url.inspect }
  end

  test "canonicalizes a post to one spelling, dropping tracking params" do
    assert_equal POST, Tiktok::Url.canonical("#{POST}?is_from_webapp=1")
    assert_equal POST, Tiktok::Url.canonical(POST)
  end

  # Dedupe compares canonical URLs, so an embed link and a post link for the
  # same video must not produce two different courses.
  test "a bare id canonicalizes through TikTok's @i placeholder handle" do
    assert_equal "https://www.tiktok.com/@i/video/#{VIDEO_ID}",
                 Tiktok::Url.canonical("https://www.tiktok.com/embed/v2/#{VIDEO_ID}")
  end

  test "a share link normalizes to scheme, host and path only" do
    assert_equal "https://vt.tiktok.com/ZSXvNVQwY",
                 Tiktok::Url.canonical("https://vt.tiktok.com/ZSXvNVQwY/?utm_source=x")
  end

  test "extracts the author handle, ignoring the @i placeholder" do
    assert_equal "scout2015", Tiktok::Url.author_handle(POST)
    assert_nil Tiktok::Url.author_handle("https://www.tiktok.com/@i/video/#{VIDEO_ID}")
  end

  # Library search runs every query through video_id. TikTok ids are long runs
  # of digits, so a loose match would turn the search "2024" into an id lookup.
  test "loose parsing is the strict parse — there is no bare-id form" do
    assert_nil Tiktok::Url.loose_video_id(VIDEO_ID)
    assert_nil Tiktok::Url.loose_canonical(VIDEO_ID)
  end
end
