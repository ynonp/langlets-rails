# Garbage-collects dynamic client registrations (RFC 7591). /oauth/register
# is unauthenticated, so scanners and abandoned connection attempts leave
# oauth_applications rows behind. A legitimate client follows registration
# with the authorization flow within minutes; a registration that never
# obtained a grant or token after STALE_AFTER is junk. Manually created
# applications (dynamically_registered: false) are never touched.
class CleanupStaleOauthRegistrationsJob < ApplicationJob
  queue_as :default

  STALE_AFTER = 48.hours

  def perform
    stale = Doorkeeper::Application
      .where(dynamically_registered: true)
      .where(created_at: ...STALE_AFTER.ago)
      .where.missing(:access_grants)
      .where.missing(:access_tokens)

    count = stale.destroy_all.size
    Rails.logger.info("CleanupStaleOauthRegistrationsJob removed #{count} stale OAuth registrations")
  end
end
