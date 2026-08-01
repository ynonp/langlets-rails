class CreateSubscriptions < ActiveRecord::Migration[8.0]
  # Langlets Pro. One row per Apple subscription *family* — StoreKit's
  # originalTransactionId is stable across every renewal, upgrade and
  # resubscribe, which is why it and not transaction_id is the natural key: a
  # renewal has to update the row it renews, not append a new one.
  #
  # Deliberately separate from credit_ledger_entries. Credits are a balance you
  # spend; a subscription is a window you are inside or outside of, and the two
  # answer different questions ("can I afford this?" vs "am I entitled?").
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true

      t.string :product_id, null: false
      t.integer :plan, null: false, default: 0
      t.integer :status, null: false, default: 0

      # Apple's identifiers. original_transaction_id is unique so that a
      # replayed StoreKit transaction, a renewal notification and a restore all
      # converge on the same row instead of racing to create three.
      t.string :original_transaction_id, null: false
      t.string :latest_transaction_id

      t.datetime :purchased_at
      t.datetime :expires_at

      # "Sandbox" or "Production". Kept because a sandbox subscription renews
      # every few minutes and is worth being able to tell apart in support.
      t.string :environment

      t.timestamps
    end

    add_index :subscriptions, :original_transaction_id, unique: true
    # Entitlement is read on every app screen through User#pro?, and it is
    # always "this user, active, not yet expired".
    add_index :subscriptions, [ :user_id, :status, :expires_at ]
  end
end
