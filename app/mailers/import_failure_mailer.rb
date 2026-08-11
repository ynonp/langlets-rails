# Operational reporting for failed imports. This is intentionally separate
# from NotificationMailer: it is triggered by Imports::Settlement, not governed
# by the requester's notification preferences, and never goes to the requester.
class ImportFailureMailer < ApplicationMailer
  RECIPIENT = "ynon@hey.com"

  def failed(import_request)
    @import_request = import_request
    @user = import_request.user
    @course = import_request.course
    @video_title = @course&.name.presence || import_request.title.presence || "Unknown video"
    @reason = import_request.failure_reason.presence || "No failure reason was recorded"

    mail(to: RECIPIENT, subject: "Course import failed: #{@video_title}")
  end
end
