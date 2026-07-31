# Guards every surface that renders course content: the course page, its
# lessons and activities, and the full player. Course readability is Channel
# visibility (see Course#readable_by?) — only Courses in a public Channel are
# world-readable.
#
# Before this existed, `courses#show` and `lessons#show` looked a Course up by
# slug and rendered it, so a private Channel hid a Course from the feeds while
# leaving its entire contents readable to anyone holding the URL.
module CourseReadable
  extend ActiveSupport::Concern

  private

  # Returns false once it has rendered, so callers can `return unless ...`.
  #
  # A guest is sent to sign in rather than 404'd because signing in may
  # genuinely grant access (they may own the Channel or be subscribed). The
  # `returnto` param — not Devise's stored location — is what this app's
  # after_sign_in_path_for honours, so it is what brings them back to the
  # course. A signed-in user who still lacks access gets a 404 rather than a
  # 403, so the response never confirms which imports exist.
  def authorize_course_read!(course)
    return true if course&.readable_by?(current_user)
    raise ActiveRecord::RecordNotFound if user_signed_in?

    destination = request.get? ? new_user_session_path(returnto: request.fullpath) : new_user_session_path
    redirect_to destination, alert: t("courses.sign_in_to_view")
    false
  end
end
