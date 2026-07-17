module Credits
  class InsufficientCredits < StandardError; end

  # The only supported way to move credits. Every call writes users.credit_balance
  # and a CreditLedgerEntry in one transaction, keyed by an idempotency_key so
  # that a retried job can't double-charge or double-refund.
  #
  #   Credits::Ledger.spend!(user:, subject: import_request,
  #                          idempotency_key: "import:#{import_request.id}")
  #   Credits::Ledger.refund!(user:, subject: import_request,
  #                           idempotency_key: "refund:#{import_request.id}")
  class Ledger
    class << self
      # Deducts credits, raising InsufficientCredits if the balance won't cover it.
      # Returns the ledger entry (the existing one on replay).
      def spend!(user:, idempotency_key:, amount: 1, reason: :import_spend, subject: nil, metadata: {})
        validate_amount!(amount)

        apply!(user:, delta: -amount, reason:, subject:, idempotency_key:, metadata:)
      end

      # Adds credits. No balance guard — grants can't fail for lack of funds.
      def grant!(user:, amount:, reason:, idempotency_key:, subject: nil, metadata: {})
        validate_amount!(amount)

        apply!(user:, delta: amount, reason:, subject:, idempotency_key:, metadata:)
      end

      # Convenience wrapper: the refund half of a failed import.
      def refund!(user:, idempotency_key:, amount: 1, subject: nil, metadata: {})
        grant!(user:, amount:, reason: :import_refund, idempotency_key:, subject:, metadata:)
      end

      private

      def validate_amount!(amount)
        raise ArgumentError, "amount must be a positive integer, got #{amount.inspect}" unless amount.is_a?(Integer) && amount.positive?
      end

      def apply!(user:, delta:, reason:, subject:, idempotency_key:, metadata:)
        # requires_new gives us a savepoint, so a lost idempotency race rolls back
        # only this block rather than poisoning an outer transaction.
        ActiveRecord::Base.transaction(requires_new: true) do
          existing = CreditLedgerEntry.find_by(idempotency_key: idempotency_key)
          next existing if existing

          apply_balance_change!(user, delta)

          CreditLedgerEntry.create!(
            user: user,
            amount: delta,
            reason: reason,
            subject: subject,
            idempotency_key: idempotency_key,
            balance_after: current_balance(user),
            metadata: metadata
          )
        end
      rescue ActiveRecord::RecordNotUnique
        # Another process wrote the same key concurrently. Our savepoint rolled
        # back, so its balance change stands alone and this call is a no-op.
        CreditLedgerEntry.find_by!(idempotency_key: idempotency_key)
      end

      # The whole concurrency story lives here. Postgres evaluates the
      # `credit_balance >= ?` predicate while holding the row lock, so of two
      # simultaneous spends against a balance of 1, exactly one sees rows == 1.
      # Never read-modify-write (`user.credit_balance -= 1; user.save!`) — that's
      # a lost update.
      #
      # Deliberately does not touch the caller's in-memory user: this runs inside
      # User's own after_create callback during signup, where a reload would fire
      # mid-save. Callers that need the new balance reload it themselves.
      def apply_balance_change!(user, delta)
        scope = User.where(id: user.id)
        scope = scope.where("credit_balance >= ?", -delta) if delta.negative?

        rows = scope.update_all([ "credit_balance = credit_balance + ?", delta ])
        raise InsufficientCredits, "user #{user.id} has insufficient credits" if rows.zero?
      end

      def current_balance(user)
        User.where(id: user.id).pick(:credit_balance)
      end
    end
  end
end
