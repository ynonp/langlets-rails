require "test_helper"

class GuestImportFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  VIDEO_ID = "kJQP7kiw5Fk".freeze
  SHARED_URL = "https://youtu.be/#{VIDEO_ID}?si=homepage".freeze
  CANONICAL_URL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

  test "the guest homepage offers Sign in instead of a link box" do
    get root_path

    assert_select "form[action=?][method=post]", guest_import_requests_path
    assert_select "#create button.lp-own-cta", text: "Sign in"
    assert_select "#create input[name=url]", count: 0
  end

  test "Sign in sends a guest to the login page and lands them on Add Video once" do
    post guest_import_requests_path

    assert_redirected_to new_user_session_path
    assert_includes response.headers["Set-Cookie"], GuestImportRequestsController::PENDING_IMPORT_COOKIE.to_s

    user = User.create!(
      email: "start-for-free@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
    assert_redirected_to new_app_import_request_path
    follow_redirect!
    assert_response :success
    assert_select "[data-controller=add-video]"

    delete destroy_user_session_path
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
    assert_redirected_to root_path
  end

  test "a guest video survives authentication and opens Add Video prefilled" do
    post guest_import_requests_path, params: { url: SHARED_URL }

    assert_redirected_to new_user_registration_path
    assert_includes response.headers["Set-Cookie"], GuestImportRequestsController::PENDING_VIDEO_COOKIE.to_s

    user = User.create!(
      email: "pending-video@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }

    assert_redirected_to new_app_import_request_path(url: CANONICAL_URL)
    follow_redirect!
    assert_response :success
    assert_select "input#web-video-url[value=?]", CANONICAL_URL
    assert_select "[data-controller=add-video]"
  end

  test "the pending video is consumed after the first successful authentication" do
    post guest_import_requests_path, params: { url: SHARED_URL }
    user = User.create!(
      email: "single-use-video@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
    assert_redirected_to new_app_import_request_path(url: CANONICAL_URL)

    delete destroy_user_session_path
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
    assert_redirected_to root_path
  end

  test "an invalid video is not saved" do
    post guest_import_requests_path, params: { url: "https://example.com/not-youtube" }

    assert_redirected_to root_path
    assert_not_includes response.headers["Set-Cookie"], GuestImportRequestsController::PENDING_VIDEO_COOKIE.to_s
  end
end
