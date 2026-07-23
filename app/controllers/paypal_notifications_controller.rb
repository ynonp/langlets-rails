class PaypalNotificationsController < ApplicationController
  skip_forgery_protection

  def create
    result = Paypal::ProcessNotification.call(raw_body: request.raw_post)
    Rails.logger.info("PayPal IPN processed: #{result.status}")
    head :ok
  rescue Paypal::Client::NotConfigured, Paypal::Client::VerificationUnavailable => e
    Rails.logger.warn("PayPal IPN verification unavailable: #{e.message}")
    head :bad_gateway
  end
end
