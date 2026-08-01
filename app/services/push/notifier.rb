module Push
  # Sends one Notification to every device a user has registered.
  #
  # Everything about APNs that used to live in SendImportReadyPushJob — the
  # per-device loop, invalidating tokens Apple says are dead, and never letting
  # one bad device take down the batch — lives here now, so a second kind of
  # notification does not mean a second copy of it.
  #
  # The badge is the user's unread count, which is what makes "entering the app
  # zeroes the badge" true: reading everything and then receiving nothing sends
  # no push, and the next push that does go out carries the new, smaller number.
  class Notifier
    def self.call(...) = new(...).call

    def initialize(notification)
      @notification = notification
      @user = notification.user
    end

    # Returns the number of devices Apple accepted.
    def call
      unless ApnsClient.configured?
        Rails.logger.info "APNs not configured; skipping push for notification #{@notification.id}"
        return 0
      end

      devices = @user.device_tokens.active.to_a
      return 0 if devices.empty?

      delivered = devices.count { |device| deliver(device) }
      Rails.logger.info "Pushed notification #{@notification.id} to #{delivered}/#{devices.size} devices"
      delivered
    end

    # What APNs is handed. `custom_payload` carries the deep link twice: `url`
    # for anything that can route a path, and `course_slug` because that is what
    # the iOS app already reads to land on Home with the new course as its hero.
    def payload
      {
        alert: { title: @notification.title, body: @notification.body },
        sound: "default",
        badge: badge,
        custom_payload: {
          notification_id: @notification.id,
          url: @notification.url,
          course_slug: @notification.data["course_slug"]
        }.compact
      }.compact
    end

    private

    # Counted at send time, not at creation time: several imports can finish
    # while the app is closed, and each push should show the running total.
    def badge
      @user.notifications.unread.count
    end

    def deliver(device)
      result = ApnsClient.push(device, payload)
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
  end
end
