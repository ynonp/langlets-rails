# Marks subscriptions whose window has closed as expired.
#
# Deliberately **not** load-bearing for access. `Subscription.entitling` reads
# `expires_at` directly, so an unrenewed subscription stops entitling Pro the
# moment it lapses whether or not this job has run — imports go back to costing
# credits and ProChannel stops granting the library on the next request. Apple
# normally confirms it through AppleNotificationsController a moment later.
#
# What this adds is that `status` stays honest for anybody reading the table:
# support answering "when did this lapse?", and any future reporting. It is a
# tidy-up, and a dropped or misconfigured App Store notification costs accuracy
# in a column rather than an entitlement somebody kept for free — which is
# exactly the property the derived design was chosen for.
class ExpireSubscriptionsJob < ApplicationJob
  queue_as :default

  def perform
    Subscription.status_active.where(expires_at: ...Time.zone.now).find_each do |subscription|
      subscription.update!(status: :expired)
    rescue => e
      Rails.logger.error("Failed to expire Subscription #{subscription.id}: #{e.message}")
    end
  end
end
