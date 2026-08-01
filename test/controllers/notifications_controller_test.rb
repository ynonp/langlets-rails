require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  NATIVE = { "User-Agent" => "LangletsNative" }.freeze

  setup do
    # Routes load lazily, and Devise builds its mappings while they are drawn.
    # A test whose first act is `sign_in` finds no mapping at all unless some
    # earlier test in the same process already forced them — which makes this an
    # order-dependent failure rather than a real one.
    Rails.application.reload_routes_unless_loaded

    @user = User.create!(email: "notifications-controller@example.com", password: "password123",
                         confirmed_at: Time.zone.now)
    @unread = Notification.create!(user: @user, kind: :course_ready, title: "Your course is ready!",
                                   body: "Tap to start practicing.", url: "/app")
    @read = Notification.create!(user: @user, kind: :pro_activated, title: "You're a Pro subscriber now",
                                 body: "Great.", read_at: 1.hour.ago)
  end

  test "signed out visitors are sent to sign in" do
    get notifications_path

    assert_redirected_to new_user_session_path
  end

  test "the list shows read and unread, and marks the unread ones new" do
    sign_in @user
    get notifications_path

    assert_response :success
    assert_select "[data-testid=notification]", count: 2
    assert_select "##{dom_id(@unread)}", text: /New/
    assert_select "##{dom_id(@read)}", text: /New/, count: 0
  end

  test "another user's notifications are not listed" do
    stranger = User.create!(email: "stranger-notifications@example.com", password: "password123",
                            confirmed_at: Time.zone.now)
    Notification.create!(user: stranger, kind: :course_ready, title: "Not yours", body: "Nope")

    sign_in @user
    get notifications_path

    assert_response :success
    assert_select "[data-testid=notification]", count: 2
  end

  test "the individual X marks one notification read and leaves the rest" do
    other_unread = Notification.create!(user: @user, kind: :course_failed, title: "Failed", body: "Sorry")
    sign_in @user

    patch read_notification_path(@unread)

    assert_redirected_to notifications_path
    assert @unread.reload.read?
    assert_not other_unread.reload.read?
  end

  test "marking read is scoped to the signed-in user" do
    stranger = User.create!(email: "stranger-read@example.com", password: "password123",
                            confirmed_at: Time.zone.now)
    theirs = Notification.create!(user: stranger, kind: :course_ready, title: "Not yours", body: "Nope")
    sign_in @user

    patch read_notification_path(theirs)

    assert_response :not_found
    assert_not theirs.reload.read?
  end

  test "mark all as read" do
    sign_in @user

    post read_all_notifications_path

    assert_redirected_to notifications_path
    assert_equal 0, @user.notifications.unread.count
  end

  # The native shell's "the user entered the app" report.
  test "read_all answers JSON with the new count" do
    sign_in @user

    post read_all_notifications_path, as: :json

    assert_response :success
    assert_equal 0, response.parsed_body["unread_count"]
    assert_equal 0, @user.notifications.unread.count
  end

  # Entering the app reports read_all as the page loads, so the list would show
  # nothing new if it read the database again after that.
  test "the list still marks what was new when the page was rendered" do
    sign_in @user
    get notifications_path
    assert_select "##{dom_id(@unread)}", text: /New/

    post read_all_notifications_path, as: :json
    get notifications_path

    assert_select "[data-testid=notification]", count: 2
    assert_select "##{dom_id(@unread)}", text: /New/, count: 0
  end

  test "the profile menu carries the unread badge" do
    sign_in @user

    get profile_path

    assert_response :success
    assert_select "a[href=?]", notifications_path
  end

  test "the native profile menu links to notifications" do
    sign_in @user
    get "/app?lang=es", headers: NATIVE

    assert_response :success
    assert_select "a[href^=?]", notifications_path
  end

  private

  def dom_id(record) = ActionView::RecordIdentifier.dom_id(record)
end
