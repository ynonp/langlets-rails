# Apple's App Store Server Notifications V2 listener.
#
# Public and unauthenticated, like the PayPal IPN endpoint next to it: the proof
# is in the payload. Every notification is a JWS carrying Apple's own
# certificate chain, so there is no shared secret to configure and nothing here
# trusts the request itself.
#
# Configure the URL in App Store Connect under the app's App Information →
# App Store Server Notifications (both the Production and Sandbox URLs):
#
#   https://langlets.app/apple/notifications
class AppleNotificationsController < ApplicationController
  skip_forgery_protection

  # Always 200 for a notification we understood, even when we chose not to act on
  # it. Apple retries any non-2xx for days, and a retry cannot fix "this is not a
  # subscription we know about".
  def create
    result = Apple::ProcessNotification.call(signed_payload: params.require(:signedPayload))
    Rails.logger.info("Apple notification processed: #{result.notification_type} → #{result.status}")
    head :ok
  rescue ActionController::ParameterMissing, ArgumentError => e
    # Not something Apple signed. Refusing it keeps a forged payload out of the
    # subscriptions table.
    Rails.logger.warn("Rejected Apple notification: #{e.message}")
    head :bad_request
  end
end
