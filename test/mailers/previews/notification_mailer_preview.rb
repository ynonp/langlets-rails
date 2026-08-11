# Preview at http://localhost:3000/rails/mailers/notification_mailer
class NotificationMailerPreview < ActionMailer::Preview
  def course_ready
    NotificationMailer.notify(preview_notification(:course_ready, course: Course.published.last))
  end

  def course_failed
    NotificationMailer.notify(
      preview_notification(:course_failed, title: "Some Video", reason: "Word translation count mismatch")
    )
  end

  def pro_activated
    NotificationMailer.notify(preview_notification(:pro_activated))
  end

  private

  # Built, not saved: a preview must not put rows in anyone's notification list.
  def preview_notification(kind, **context)
    content = Notifications::Content.build(kind, context)

    Notification.new(
      id: 0, user: User.first, kind: kind,
      url: content.url, data: content.data,
      created_at: Time.zone.now
    )
  end
end
