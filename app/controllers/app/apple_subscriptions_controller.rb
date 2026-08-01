module App
  # Langlets Pro purchases and restores — the only in-app purchase there is.
  # There was a sibling ApplePurchasesController for consumable credit packs;
  # credits are no longer sold, so it is gone. The `catalog:` argument it existed
  # to differ on stays required (see Apple::VerifyTransaction): an endpoint has
  # to name the kind of product it will grant.
  class AppleSubscriptionsController < BaseController
    def create
      payload, = Apple::VerifyTransaction.new(
        signed_transaction: params.require(:signed_transaction),
        user: current_user,
        catalog: Apple::SubscriptionPlans
      ).call

      subscription = Apple::ActivateSubscription.call(payload: payload, user: current_user)

      # A transaction can verify and still not entitle anyone — an expired one
      # replayed from a restore, most likely. Say so rather than sending the app
      # to a success screen it would immediately contradict.
      unless subscription&.entitling?
        return render json: { error: "subscription_not_active" }, status: :unprocessable_content
      end

      render json: { pro: true, redirect: app_pro_success_path }
    rescue ActionController::ParameterMissing, ArgumentError
      render json: { error: "invalid_transaction" }, status: :unprocessable_content
    end
  end
end
