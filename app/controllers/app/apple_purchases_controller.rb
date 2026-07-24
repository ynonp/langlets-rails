module App
  class ApplePurchasesController < BaseController
    def create
      payload, pack = Apple::VerifyTransaction.new(
        signed_transaction: params.require(:signed_transaction),
        user: current_user
      ).call

      Credits::Ledger.grant!(
        user: current_user,
        amount: pack.credits,
        reason: :iap_purchase,
        idempotency_key: "apple:#{payload.fetch("transactionId")}",
        metadata: {
          provider: "apple",
          transaction_id: payload["transactionId"],
          original_transaction_id: payload["originalTransactionId"],
          product_id: pack.product_id
        }
      )

      render json: { credits: current_user.reload.credit_balance }
    rescue ActionController::ParameterMissing, ArgumentError
      render json: { error: "invalid_transaction" }, status: :unprocessable_content
    end
  end
end
