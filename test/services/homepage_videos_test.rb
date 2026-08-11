require "test_helper"

class HomepageVideosTest < ActiveSupport::TestCase
  test "for_page returns eight unique random examples without depending on YAML contents" do
    videos = 12.times.map do |index|
      HomepageVideos::Video.new(
        title: "Video #{index}",
        url: "https://www.youtube.com/watch?v=video#{index}",
        clip_language: "Spanish",
        thumbnail_url: "https://example.com/video#{index}.jpg"
      )
    end

    first = HomepageVideos.stub(:all, videos) { HomepageVideos.for_page(random: Random.new(1)) }
    second = HomepageVideos.stub(:all, videos) { HomepageVideos.for_page(random: Random.new(2)) }

    assert_equal 8, first.size
    assert_equal first.size, first.uniq.size
    assert_empty first - videos
    refute_equal first, second
  end

  test "for_page returns every example when YAML contains fewer than eight" do
    videos = HomepageVideos.all.first(3)

    selection = HomepageVideos.stub(:all, videos) { HomepageVideos.for_page(random: Random.new(1)) }

    assert_equal videos.sort_by(&:url), selection.sort_by(&:url)
  end
end
