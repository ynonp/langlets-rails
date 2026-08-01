require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "notify-model@example.com", password: "password123", confirmed_at: Time.zone.now)
  end

  def build_notification(**overrides)
    Notification.create!({ user: @user, kind: :course_ready, title: "Ready", body: "Body" }.merge(overrides))
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
    theirs = Notification.create!(user: stranger, kind: :pro_activated, title: "Pro", body: "Body")

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
end
