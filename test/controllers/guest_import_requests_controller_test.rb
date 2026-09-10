require "test_helper"

class GuestImportRequestsControllerTest < ActionDispatch::IntegrationTest
  URL = "https://www.youtube.com/watch?v=kJQP7kiw5Fk".freeze

  test "a direct guest submission cannot create records for a long video" do
    video = VideoSource::Video.new(
      video_id: "kJQP7kiw5Fk",
      title: "Long example",
      author_name: "Teacher",
      thumbnail_url: "https://example.com/thumb.jpg",
      canonical_url: URL
    )

    VideoSource.stub(:fetch, video) do
      Imports::VideoPreflight.stub(:fetch_duration, 4_744) do
        post guest_import_requests_path, params: { url: URL }
      end
    end

    assert_redirected_to root_path
    assert_match "up to 20 minutes", flash[:alert]
    assert_equal 0, EvaluationSignup.count
    assert_equal 0, ImportRequest.count
  end
end
