module App
  # Langlets Pro: the paywall and its confirmation.
  #
  # The purchase itself happens in StoreKit, between these two screens — there is
  # no server-rendered step in the middle. `#success` is reached only after
  # AppleSubscriptionsController has verified the transaction and written the
  # entitlement, which is why it can assert Pro rather than ask.
  class ProController < BaseController
    # Every Pro CTA in the app links here, so this one guard is what keeps the
    # Android shell from reaching a paywall it cannot transact. Its "Continue —
    # $100/year" button is wired to the `apple-purchase` bridge component, which
    # Android does not register, so the button would be inert and the fine print
    # ("Billed through the App Store") would be describing a store the device
    # does not have. Send them back with the same sentence the web gets, which
    # already names where the subscription is sold.
    before_action :require_purchasable_platform

    def show
      # Already Pro: the paywall has nothing to sell and a second subscription is
      # the one outcome nobody wants. Send them to the confirmation, which
      # doubles as the "what you have" screen.
      return redirect_to app_pro_success_path if current_user.pro?

      @plans = Apple::SubscriptionPlans.all
      @default_plan = Apple::SubscriptionPlans.yearly
      @yearly_savings_percent = Apple::SubscriptionPlans.yearly_savings_percent
      @free_imports_used = current_user.free_imports_used
      @apple_app_account_token = Apple::AppAccountToken.for(current_user)
    end

    def success
      @subscription = current_user.pro_subscription

      # Landing here without an entitlement means the purchase never completed —
      # a cancelled StoreKit sheet, or a stale back-navigation. Showing "You're
      # Pro!" then would be a straight lie, so go back to the offer.
      redirect_to app_pro_path if @subscription.nil?
    end

    private

    def require_purchasable_platform
      # An existing subscriber is not being sold anything: #show forwards them to
      # #success, which is the "what you have" screen. Someone who subscribed on
      # their iPhone and then signed in on Android should still be able to see
      # it, so only the purchase itself is gated, not the status.
      return if can_purchase_pro? || current_user.pro?

      redirect_to app_home_path,
                  alert: t("app.import_requests.new.out_of_credits_web_hint")
    end
  end
end
