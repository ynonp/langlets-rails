module App
  # Langlets Pro: the paywall and its confirmation.
  #
  # The purchase itself happens in StoreKit, between these two screens — there is
  # no server-rendered step in the middle. `#success` is reached only after
  # AppleSubscriptionsController has verified the transaction and written the
  # entitlement, which is why it can assert Pro rather than ask.
  class ProController < BaseController
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
  end
end
