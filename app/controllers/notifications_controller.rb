# The user's notification list, on both clients.
#
# One controller and one view for web and the native shell: the only difference
# is the layout, picked the same way the Profile page picks it, so the copy and
# the read/unread rules can't drift between the two.
class NotificationsController < ApplicationController
  before_action :authenticate_user!

  PER_PAGE = 100

  def index
    @notifications = current_user.notifications.recent.limit(PER_PAGE).to_a
    # Snapshotted before anything marks them read, so a native launch — which
    # reports read_all as the page loads — still shows the user what was new.
    @unread_ids = @notifications.reject(&:read?).map(&:id).to_set

    # Entering this page is itself "the user has seen what's new", same as the
    # native shell's launch report. Marking read here (after the snapshot
    # above) is what makes the header/menu badge gone by the time this page
    # renders, on web as well as native.
    Notification.mark_all_read!(current_user)
  end

  # The individual "X". Marking read, not deleting: the list is the record of
  # what the app has told this user.
  def read
    notification = current_user.notifications.find(params[:id])
    notification.mark_read!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(notification), partial: "notifications/notification", locals: { notification: notification, unread: false }) }
      format.html { redirect_to notifications_path }
    end
  end

  # Two callers: the "Mark all as read" button, and the native shell reporting
  # that the user entered the app. Both mean the same thing, which is why they
  # are the same endpoint.
  def read_all
    Notification.mark_all_read!(current_user)

    respond_to do |format|
      # The native shell's launch report, which wants an answer rather than a page.
      format.json { render json: { unread_count: 0 } }
      format.any { redirect_to notifications_path }
    end
  end

  private

  def dom_id(record) = ActionView::RecordIdentifier.dom_id(record)
end
