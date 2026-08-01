# The notification subsystem's front door.
#
#   Notifications.deliver(user: user, kind: :course_ready, course: course)
#
# Callers should not reach past this into Notification, DeliverNotificationJob
# or Push::Notifier — those are how it works, this is what it does. The
# supported kinds and their wording live in Notifications::Content.
module Notifications
  module_function

  def deliver(user:, kind:, **context)
    Deliver.call(user: user, kind: kind, **context)
  end
end
