class AddCreditBalanceToUsers < ActiveRecord::Migration[8.0]
  # The authoritative, concurrency-safe balance. Credits::Ledger spends with a
  # conditional UPDATE (`WHERE credit_balance >= ?`), which evaluates the
  # predicate under the row lock, so two simultaneous imports from a balance of 1
  # can't both win. The CHECK constraint is the backstop if anything ever writes
  # the column without going through the ledger.
  def change
    add_column :users, :credit_balance, :integer, null: false, default: 0
    add_check_constraint :users, "credit_balance >= 0", name: "credit_balance_non_negative"
  end
end
