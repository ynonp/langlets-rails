require "test_helper"

class TryControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

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

  test "homepage shows a useful error after an unreadable video redirects back" do
    VideoSource.stub(:fetch, ->(_url) { raise VideoSource::UnavailableVideo, "private" }) do
      get try_path(url: URL)
    end
    follow_redirect!

    assert_response :success
    assert_select "[role=alert]", text: /private, age-restricted, deleted, region-blocked/
  end

  test "homepage rejects a long video before showing signup actions" do
    VideoSource.stub(:fetch, @video) do
      Imports::VideoPreflight.stub(:fetch_duration, 4_744) do
        get try_path(url: URL)
      end
    end
    follow_redirect!

    assert_response :success
    assert_select "[role=alert]", text: /up to 20 minutes/
    assert_select "form[action=?]", guest_import_requests_path, count: 0
  end

  test "a signed-in user creates from the reviewed preview without another approval" do
    user = User.create!(email: "try-import@example.com", password: "password123", confirmed_at: Time.zone.now)
    sign_in user

    Imports::VideoPreflight.stub(:fetch_duration, 90) do
      VideoSource.stub(:fetch, @video) do
        get try_path(url: URL)
      end
    end

    assert_response :success
    assert_select "form[action=?][method=post]", app_import_requests_path do
      assert_select "input[name=url][value=?]", URL
      assert_select "button", text: "Create this Langlet"
    end
    assert_select "a[href^=?]", new_app_import_request_path, count: 0

    assert_enqueued_with(job: DetectImportLanguageJob) do
      Imports::VideoPreflight.stub(:fetch_duration, 90) do
        VideoSource.stub(:fetch, @video) do
          post app_import_requests_path, params: { url: URL }
        end
      end
    end

    assert_redirected_to gallery_path(imports: "pending")
    assert user.import_requests.sole.detecting?
  end
end
