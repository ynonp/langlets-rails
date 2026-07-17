class GrantSignupCreditsToExistingUsers < ActiveRecord::Migration[8.0]
  # Users who existed before credits did get the same 3 free credits a new signup
  # gets. New accounts are handled by User#grant_signup_credits.
  #
  # Deliberately raw SQL and self-reconciling rather than looping through the
  # model: the entry uses the same "signup:<id>" idempotency key the callback
  # would, so re-running this (or a later replay) is a no-op, and the balance is
  # recomputed from the ledger rather than assumed — which keeps the two in
  # agreement even if this runs after credits have been spent.
  #
  # reason = 0 is CreditLedgerEntry.reasons[:signup_grant].
  def up
    execute <<~SQL.squish
      INSERT INTO credit_ledger_entries
        (user_id, amount, reason, balance_after, idempotency_key, metadata, created_at, updated_at)
      SELECT u.id, 3, 0, 3, 'signup:' || u.id, '{}'::jsonb, now(), now()
        FROM users u
       WHERE NOT EXISTS (
         SELECT 1 FROM credit_ledger_entries e
          WHERE e.idempotency_key = 'signup:' || u.id
       )
    SQL

    execute <<~SQL.squish
      UPDATE users u
         SET credit_balance = COALESCE(
           (SELECT SUM(e.amount) FROM credit_ledger_entries e WHERE e.user_id = u.id), 0
         )
    SQL
  end

  def down
    execute "DELETE FROM credit_ledger_entries WHERE reason = 0"
    execute "UPDATE users SET credit_balance = 0"
  end
end
