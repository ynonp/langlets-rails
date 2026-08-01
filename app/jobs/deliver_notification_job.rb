# Delivers one Notification over whichever channels the user asked for.
#
# Idempotent on `sent_at`: a retry of a job that already delivered must not mail
# or push the user a second time. That stamp means "delivery was attempted",
# not "it arrived" — a bounced email and a dead device token are both still
# attempts, and the notification is on /notifications either way.
class DeliverNotificationJob < ApplicationJob
  queue_as :default

  def perform(notification_id)
    notification = Notification.find_by(id: notification_id)
    return if notification.nil?
    return if notification.sent_at.present?

    user = notification.user
    deliver_email(notification) if user.email_notifications?
    deliver_push(notification) if user.push_notifications?

    # Stamped even when a channel failed, and even when the user turned both of
    # them off: this is the last word on "we tried", and a user who wants
    # neither should not accumulate work that retries forever.
    notification.update_columns(sent_at: Time.zone.now, updated_at: Time.zone.now)
  end

  private

  # Neither channel may take the other down with it: a mail server refusing
  # connections must not cost the user their push, and vice versa.
  def deliver_email(notification)
    NotificationMailer.notify(notification).deliver_now
  rescue StandardError => e
    Rails.logger.error "Notification #{notification.id} email failed: #{e.class}: #{e.message}"
  end

  def deliver_push(notification)
    Push::Notifier.call(notification)
  rescue StandardError => e
    Rails.logger.error "Notification #{notification.id} push failed: #{e.class}: #{e.message}"
  end
end
