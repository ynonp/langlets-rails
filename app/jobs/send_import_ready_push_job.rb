# Tells the user their import finished.
#
# This is the signal the whole Queue design leans on — the product promise is
# "close the app, we'll ping you", which is why the Queue polls instead of
# holding a socket open.
class SendImportReadyPushJob < ApplicationJob
  queue_as :default

  def perform(import_request_id)
    import_request = ImportRequest.find_by(id: import_request_id)
    return if import_request.nil?

    # Idempotent: a re-run must not ping twice.
    return if import_request.notified_at.present?
    return unless import_request.ready?

    unless Push::ApnsClient.configured?
      Rails.logger.info "APNs not configured; skipping push for import #{import_request.id}"
      return
    end

    devices = import_request.user.device_tokens.active.to_a
    if devices.empty?
      # Nothing to send to — but mark it done so we don't retry forever for a
      # user who has never granted permission. The completion email still went.
      import_request.update_columns(notified_at: Time.zone.now, updated_at: Time.zone.now)
      return
    end

    payload = Push::CourseReadyNotification.payload_for(import_request, badge: badge_for(import_request.user))
    delivered = devices.count { |device| deliver(device, payload) }

    # Stamped even when every device failed: a user whose token went stale
    # shouldn't get a burst of pushes when they reinstall.
    import_request.update_columns(notified_at: Time.zone.now, updated_at: Time.zone.now)

    Rails.logger.info "Pushed import #{import_request.id} to #{delivered}/#{devices.size} devices"
  end

  private

  def deliver(device, payload)
    result = Push::ApnsClient.push(device, payload)
    return true if result.ok?

    if result.token_dead?
      # Apple says this install is gone. Kept, not deleted — re-registering
      # revives it, and it makes "why did I stop getting pushes?" answerable.
      device.invalidate!
      Rails.logger.info "APNs token #{device.id} invalidated (#{result.status} #{result.reason})"
    else
      Rails.logger.warn "APNs push to device #{device.id} failed: #{result.status} #{result.reason}"
    end

    false
  rescue StandardError => e
    # One bad device must not take down the rest of the batch.
    Rails.logger.error "APNs push to device #{device.id} raised: #{e.message}"
    false
  end

  # The app icon badge shows what's waiting: imports that finished and haven't
  # been opened yet.
  def badge_for(user)
    user.import_requests.ready.where(updated_at: 48.hours.ago..).count
  end
end
