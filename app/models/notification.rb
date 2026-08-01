# One thing the app has to tell one user.
#
# The row is the record, not a side effect of delivery: it is created first and
# always, then email and push are attempted against it according to the user's
# preference (see DeliverNotificationJob). A user who receives neither still has
# a complete list on /notifications, which is what makes the preference safe to
# offer at all.
#
# The copy lives on the row rather than being rebuilt at render time. Email,
# push and the list must say the same thing, and a notification about a course
# has to keep making sense after that course is deleted — so `title`, `body`
# and `url` are written once, by Notifications::Content, and never recomputed.
class Notification < ApplicationRecord
  belongs_to :user

  # Persisted as an integer; keep the values stable. Add new kinds to
  # Notifications::Content at the same time — it is what knows how to word them.
  enum :kind, { course_ready: 0, course_failed: 1, pro_activated: 2 }, prefix: true

  validates :title, :body, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def read? = read_at.present?

  # Idempotent: re-reading must not move the timestamp, so a "mark all read" on
  # every app launch cannot rewrite history.
  def mark_read!
    return if read?

    update!(read_at: Time.zone.now)
  end

  # The "entering the app means you read everything" event, and the web page's
  # "Mark all as read". One UPDATE rather than a load-and-save loop: this runs on
  # app launch and the count is unbounded.
  def self.mark_all_read!(user)
    user.notifications.unread.update_all(read_at: Time.zone.now, updated_at: Time.zone.now)
  end
end
