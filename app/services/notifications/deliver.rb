module Notifications
  # The one way to tell a user something.
  #
  #   Notifications::Deliver.call(user: user, kind: :course_ready, course: course)
  #
  # Records first, delivers second. The Notification row is committed before any
  # mail or push is attempted, so a dead APNs token or a bouncing mailbox costs
  # the user the banner and not the message: it is still on /notifications.
  #
  # Delivery is a job rather than inline work because both callers are things
  # that have already succeeded — an import that finished, a subscription that
  # activated — and neither may be failed by a notification.
  module Deliver
    module_function

    # Returns the created Notification, or nil when there is no user to tell.
    def call(user:, kind:, **context)
      return nil if user.nil?

      content = Content.build(kind, context)

      notification = Notification.create!(
        user: user,
        kind: kind,
        title: content.title,
        body: content.body,
        url: content.url,
        data: content.data
      )

      DeliverNotificationJob.perform_later(notification.id)
      notification
    end
  end
end
