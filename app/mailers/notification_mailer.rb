# The email side of the notification subsystem.
#
# One action for every kind, because a Notification already carries its own
# words (see Notifications::Content) — a mailer method per kind would put the
# same sentence in a second place and let the two drift, which is what this
# rewrite exists to stop.
class NotificationMailer < ApplicationMailer
  def notify(notification)
    @notification = notification
    @user = notification.user
    # Anything the body deliberately leaves out but the reader may want. Today
    # that is the pipeline's failure message on a failed import.
    @details = notification.data["reason"].presence
    @action_url = action_url(notification)

    mail(to: @user.email, subject: notification.title)
  end

  private

  # Notification#url is an in-app path; email needs an absolute URL. A
  # notification with no path at all still has somewhere sensible to send them.
  def action_url(notification)
    path = notification.url.presence || "/"
    URI.join(root_url, path).to_s
  rescue URI::Error
    root_url
  end
end
