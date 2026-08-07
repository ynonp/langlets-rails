require "test_helper"

# The subsystem's front door: record first, deliver second.
class NotificationsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  VIDEO_ID = "notifyVid1".freeze
  CANONICAL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

  setup do
    @user = User.create!(email: "notify-service@example.com", password: "password123", confirmed_at: Time.zone.now)
    @spanish = languages(:spanish)
    @english = languages(:english)
    @medium = Medium.create!(url: CANONICAL, language: @spanish)
    @course = create_translated_course!(
      name: "Despacito", slug: "despacito-notify", main_media_url: CANONICAL,
      youtube_video_id: VIDEO_ID, language: @spanish, translation_language: @english,
      user: @user, status: :published
    )
    2.times { |i| Lesson.create!(course: @course, medium: @medium, user: @user, slug: "n#{i}", name: "L#{i}", order: i) }
  end

  test "delivering records the notification and queues its delivery" do
    notification = nil

    assert_enqueued_with(job: DeliverNotificationJob) do
      notification = Notifications.deliver(user: @user, kind: :course_ready, course: @course)
    end

    assert notification.persisted?
    assert notification.kind_course_ready?
    assert_nil notification.sent_at, "delivery has not been attempted yet"
    assert_nil notification.read_at
  end

  test "course_ready says what the app has always said" do
    notification = Notifications.deliver(user: @user, kind: :course_ready, course: @course)

    assert_equal "“Despacito” is ready!", notification.title
    assert_equal "“Despacito” is now 2 lessons. Tap to start practicing.", notification.body
    assert_equal "/courses/despacito-notify", notification.url
    assert_equal "despacito-notify", notification.data["course_slug"]
  end

  test "course_ready counts persisted lessons when the association cache is stale" do
    course = create_translated_course!(
      name: "New Song", slug: "new-song-notify", main_media_url: "https://www.youtube.com/watch?v=staleCount1",
      youtube_video_id: "staleCount1", language: @spanish, translation_language: @english,
      user: @user, status: :published
    )
    course.lessons.load
    Lesson.create!(course: course, medium: @medium, user: @user, slug: "new-lesson", name: "New lesson")

    notification = Notifications.deliver(user: @user, kind: :course_ready, course: course)

    assert_equal 0, course.lessons.size, "the test must preserve the pipeline's stale association state"
    assert_equal 1, notification.data["count"]
    assert_equal "“New Song” is now 1 lesson. Tap to start practicing.", notification.body
  end

  # The copy is written once, onto the row, so the course going away cannot
  # turn a notification into a blank line or an exception.
  test "a notification outlives the course it is about" do
    notification = Notifications.deliver(user: @user, kind: :course_ready, course: @course)
    @course.destroy

    assert_equal "“Despacito” is now 2 lessons. Tap to start practicing.", notification.reload.body
  end

  test "course_failed keeps the pipeline's reason out of the body" do
    notification = Notifications.deliver(
      user: @user, kind: :course_failed, course: @course, reason: "Word translation count mismatch"
    )

    assert_equal "Course creation failed", notification.title
    assert_includes notification.body, "Despacito"
    assert_not_includes notification.body, "mismatch"
    assert_equal "Word translation count mismatch", notification.data["reason"]
  end

  # A failed import has nothing specific to open, so the list and the push
  # payload should offer no "Open" at all rather than a generic screen.
  test "course_failed has no url" do
    notification = Notifications.deliver(user: @user, kind: :course_failed, course: @course, reason: "boom")

    assert_nil notification.url
  end

  # A failed import may never have got as far as a Course row; the request's
  # title is all there is.
  test "course_failed falls back to the requested title when there is no course" do
    notification = Notifications.deliver(user: @user, kind: :course_failed, title: "Some Song", reason: "boom")

    assert_includes notification.body, "Some Song"
  end

  test "pro_activated" do
    notification = Notifications.deliver(user: @user, kind: :pro_activated)

    assert_equal "You're a Pro subscriber now", notification.title
    assert notification.kind_pro_activated?
  end

  test "an unknown kind is a loud failure rather than an empty notification" do
    assert_raises(Notifications::Content::UnknownKind) do
      Notifications.deliver(user: @user, kind: :something_new)
    end
  end

  test "no user, no notification" do
    assert_no_difference -> { Notification.count } do
      assert_nil Notifications.deliver(user: nil, kind: :pro_activated)
    end
  end
end
