require "test_helper"

# Settlement is where every import ends, either way — which is why it is the
# single place both the "ready" and the "failed" notification come from.
class Imports::SettlementNotificationsTest < ActiveSupport::TestCase
  VIDEO_ID = "settleVid01".freeze
  CANONICAL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

  setup do
    @user = User.create!(email: "settlement-notify@example.com", password: "password123", confirmed_at: Time.zone.now)
    @spanish = languages(:spanish)
    @english = languages(:english)
    @course = create_translated_course!(
      name: "Despacito", slug: "despacito-settle", main_media_url: CANONICAL,
      youtube_video_id: VIDEO_ID, language: @spanish, translation_language: @english,
      user: @user, status: :published
    )
    @request = create_request
  end

  test "completing an import tells the user their course is ready" do
    Imports::Settlement.complete!(@request)

    notification = @user.notifications.sole
    assert notification.kind_course_ready?
    assert_equal "/courses/despacito-settle", notification.url
  end

  # Imports::Create adopting a course the user is already looking at.
  test "notify: false stays quiet" do
    Imports::Settlement.complete!(@request, notify: false)

    assert_equal 0, @user.notifications.count
  end

  test "failing an import tells the user, with the reason kept for the email" do
    Imports::Settlement.fail!(@request, "Word translation count mismatch")

    notification = @user.notifications.sole
    assert notification.kind_course_failed?
    assert_equal "Word translation count mismatch", notification.data["reason"]
  end

  # The finalizer and the timeout job can both conclude the same import failed.
  test "failing an already-failed import does not tell the user twice" do
    Imports::Settlement.fail!(@request, "boom")
    Imports::Settlement.fail!(@request.reload, "boom again")

    assert_equal 1, @user.notifications.count
  end

  # On a joined import the creator and the person waiting are different people.
  test "the failure goes to whoever asked, not to the course's creator" do
    rider = User.create!(email: "rider@example.com", password: "password123", confirmed_at: Time.zone.now)
    theirs = create_request(user: rider)

    Imports::Settlement.fail!(theirs, "boom")

    assert_equal 1, rider.notifications.count
    assert_equal 0, @user.notifications.count
  end

  private

  def create_request(user: @user)
    ImportRequest.create!(
      user: user, youtube_url: CANONICAL, youtube_video_id: VIDEO_ID,
      clip_language: "Spanish", translation_language: "English", title: "Despacito",
      status: :importing, course: @course
    )
  end
end
