class CreateCreditLedgerEntries < ActiveRecord::Migration[8.0]
  # Append-only audit of every credit movement. users.credit_balance is the fast,
  # lockable authority; this is the "why", and what makes refunds and support
  # questions answerable. The two are written in one transaction and reconciled
  # by CreditReconciliationJob.
  def change
    create_table :credit_ledger_entries do |t|
      t.references :user, null: false, foreign_key: true

      # Signed: +3 signup grant, -1 import spend, +1 refund.
      t.integer :amount, null: false
      t.integer :reason, null: false

      # Balance immediately after this entry, for auditing without replaying.
      t.integer :balance_after, null: false

      # ImportRequest today; IapTransaction when purchases land.
      t.references :subject, polymorphic: true, null: true

      # The safety story: GoodJob retries, so every caller passes a stable key
      # ("import:42", "refund:42", "signup:7") and a replay is a no-op.
      t.string :idempotency_key, null: false

      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :credit_ledger_entries, :idempotency_key, unique: true
    add_index :credit_ledger_entries, [ :user_id, :created_at ]
  end
end
