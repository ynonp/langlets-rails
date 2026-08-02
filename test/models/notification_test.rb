require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "notify-model@example.com", password: "password123", confirmed_at: Time.zone.now)
  end

  def build_notification(**overrides)
    Notification.create!(
      { user: @user, kind: :course_ready, data: { "video_title" => "Despacito", "count" => 2 } }.merge(overrides)
    )
  end

  test "a new notification is unread and unsent" do
    notification = build_notification

    assert_not notification.read?
    assert_nil notification.sent_at
    assert_includes Notification.unread, notification
  end

  test "mark_read! stamps once and never moves" do
    notification = build_notification
    notification.mark_read!
    first = notification.read_at

    travel 1.hour do
      notification.mark_read!
    end

    assert_equal first, notification.reload.read_at
  end

  test "mark_all_read! reads this user's unread and leaves everyone else alone" do
    mine = build_notification
    already_read = build_notification
    already_read.mark_read!
    stranger = User.create!(email: "stranger@example.com", password: "password123", confirmed_at: Time.zone.now)
    theirs = Notification.create!(user: stranger, kind: :pro_activated)

    read_at_before = already_read.read_at

    Notification.mark_all_read!(@user)

    assert mine.reload.read?
    assert_equal read_at_before.to_i, already_read.reload.read_at.to_i
    assert_not theirs.reload.read?
  end

  test "recent orders newest first" do
    older = build_notification
    older.update_columns(created_at: 2.days.ago)
    newer = build_notification

    assert_equal [ newer.id, older.id ], @user.notifications.recent.pluck(:id)
  end

  test "deleting the user takes their notifications with it" do
    build_notification
    assert_difference -> { Notification.count }, -1 do
      @user.destroy
    end
  end

  # ------------------------------------------------------------------ copy

  test "copy is rendered from the row's values" do
    notification = build_notification

    assert_equal "“Despacito” is ready!", notification.title
    assert_equal "“Despacito” is now 2 lessons. Tap to start practicing.", notification.body
  end

  # The reason the copy moved off the row: an edit reaches notifications that
  # were sent before it was made.
  test "editing the wording changes notifications that already exist" do
    notification = build_notification

    with_translation("notifications.kinds.course_ready.title", "Ready to practice") do
      assert_equal "Ready to practice", notification.title
    end
  end

  test "the list renders in the reader's language" do
    notification = build_notification

    assert_equal "הקורס “Despacito” מוכן!", notification.title(locale: :he)
  end

  # i18n pluralizes on `count`, which is what makes this right in languages
  # whose plural rules are not "add an s".
  test "one lesson is a lesson" do
    notification = build_notification(data: { "video_title" => "Despacito", "count" => 1 })

    assert_equal "“Despacito” is now 1 lesson. Tap to start practicing.", notification.body
  end

  # A failed import may never have learned what it was importing. The stand-in
  # is copy, so it comes from the locale file and not from the row.
  test "a notification with no captured title still reads" do
    notification = build_notification(kind: :course_failed, data: {})

    assert_includes notification.body, "Your video"
    assert_includes notification.body(locale: :he), "הסרטון שלכם"
  end

  # One unrenderable row must not cost the reader the other ninety-nine.
  test "a template that lost an interpolation degrades instead of raising" do
    notification = build_notification

    with_translation("notifications.kinds.course_ready.body", "About %{something_new}") do
      assert_equal "This notification is no longer available.", notification.body
    end
  end

  private

  # Stands in for someone editing en.yml. The lookup first is not decoration:
  # the backend loads the locale files lazily, on the first miss, and would
  # otherwise load them *over* the override we are about to store.
  def with_translation(key, value)
    I18n.t(key)
    I18n.backend.store_translations(:en, key.split(".").reverse.inject(value) { |acc, k| { k => acc } })
    yield
  ensure
    I18n.backend.reload!
  end
end
