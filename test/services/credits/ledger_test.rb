require "test_helper"

module Credits
  class LedgerTest < ActiveSupport::TestCase
    setup do
      @user = create_user("ledger@example.com")
    end

    test "a new user starts with three credits and a matching ledger entry" do
      assert_equal User::SIGNUP_CREDITS, @user.credit_balance

      entry = @user.credit_ledger_entries.sole
      assert entry.signup_grant?
      assert_equal 3, entry.amount
      assert_equal 3, entry.balance_after
      assert_equal "signup:#{@user.id}", entry.idempotency_key
    end

    test "spend! deducts from the balance and records the entry" do
      entry = Ledger.spend!(user: @user, idempotency_key: "import:1")

      assert_equal 2, @user.reload.credit_balance
      assert entry.import_spend?
      assert_equal(-1, entry.amount)
      assert_equal 2, entry.balance_after
    end

    test "spend! raises InsufficientCredits when the balance is empty" do
      3.times { |i| Ledger.spend!(user: @user, idempotency_key: "import:#{i}") }
      assert_equal 0, @user.reload.credit_balance

      assert_raises(InsufficientCredits) do
        Ledger.spend!(user: @user, idempotency_key: "import:broke")
      end

      assert_equal 0, @user.reload.credit_balance, "a rejected spend must not move the balance"
    end

    # GoodJob retries jobs, so the same spend can be attempted twice. Without the
    # idempotency key that would charge the user twice for one import.
    test "spend! with a repeated idempotency key charges only once" do
      first  = Ledger.spend!(user: @user, idempotency_key: "import:42")
      second = Ledger.spend!(user: @user, idempotency_key: "import:42")

      assert_equal first.id, second.id
      assert_equal 2, @user.reload.credit_balance
      assert_equal 1, @user.credit_ledger_entries.import_spend.count
    end

    test "refund! returns the credit and is also idempotent" do
      Ledger.spend!(user: @user, idempotency_key: "import:7")
      assert_equal 2, @user.reload.credit_balance

      Ledger.refund!(user: @user, idempotency_key: "refund:7")
      Ledger.refund!(user: @user, idempotency_key: "refund:7")

      assert_equal 3, @user.reload.credit_balance
      assert_equal 1, @user.credit_ledger_entries.import_refund.count
    end

    test "grant! adds credits" do
      Ledger.grant!(user: @user, amount: 5, reason: :promo_grant, idempotency_key: "promo:x")

      assert_equal 8, @user.reload.credit_balance
    end

    test "amount must be a positive integer" do
      assert_raises(ArgumentError) { Ledger.spend!(user: @user, amount: 0, idempotency_key: "a") }
      assert_raises(ArgumentError) { Ledger.spend!(user: @user, amount: -1, idempotency_key: "b") }
      assert_raises(ArgumentError) { Ledger.grant!(user: @user, amount: 0, reason: :promo_grant, idempotency_key: "c") }
    end

    test "the ledger sum always agrees with the balance" do
      Ledger.spend!(user: @user, idempotency_key: "import:1")
      Ledger.spend!(user: @user, idempotency_key: "import:2")
      Ledger.refund!(user: @user, idempotency_key: "refund:2")

      assert_equal @user.reload.credit_balance, @user.credit_ledger_entries.sum(:amount)
    end

    test "ledger entries are immutable once written" do
      entry = Ledger.spend!(user: @user, idempotency_key: "import:1")

      assert entry.readonly?
      assert_raises(ActiveRecord::ReadOnlyRecord) { entry.update!(amount: -99) }
      assert_raises(ActiveRecord::ReadOnlyRecord) { entry.destroy }
    end

    # The account-deletion path: CreditLedgerEntry refuses destroy, so the
    # association has to delete_all or deleting a user raises ReadOnlyRecord.
    test "deleting a user removes their ledger without tripping immutability" do
      Ledger.spend!(user: @user, idempotency_key: "import:1")
      user_id = @user.id

      assert_nothing_raised { @user.destroy }
      assert_equal 0, CreditLedgerEntry.where(user_id: user_id).count
    end

    private

    def create_user(email)
      User.create!(email: email, password: "password123", confirmed_at: Time.zone.now)
    end
  end

  # Separate class: transactional fixtures would hide the rows from the other
  # thread's connection, so this one manages its own data.
  class LedgerConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      @user = User.create!(email: "concurrency@example.com", password: "password123",
                           confirmed_at: Time.zone.now)
      # Straight to the column: this is fixture setup, not a credit movement.
      User.where(id: @user.id).update_all(credit_balance: 1)
    end

    teardown do
      CreditLedgerEntry.where(user_id: @user.id).delete_all
      User.where(id: @user.id).delete_all
    end

    # The highest-value test here. Two real threads on two real connections spend
    # the last credit at the same time. The conditional UPDATE evaluates
    # `credit_balance >= 1` under the row lock, so exactly one wins. A
    # read-modify-write implementation lets both through and the balance goes
    # negative.
    test "only one of two concurrent spends succeeds" do
      barrier = Concurrent::CyclicBarrier.new(2) if defined?(Concurrent::CyclicBarrier)
      results = Queue.new

      threads = 2.times.map do |i|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            barrier&.wait
            begin
              Ledger.spend!(user: User.find(@user.id), idempotency_key: "concurrent-import:#{i}")
              results << :ok
            rescue InsufficientCredits
              results << :rejected
            end
          end
        end
      end
      threads.each(&:join)

      outcomes = []
      outcomes << results.pop until results.empty?

      assert_equal 1, outcomes.count(:ok),       "exactly one spend should succeed, got #{outcomes.inspect}"
      assert_equal 1, outcomes.count(:rejected), "exactly one spend should be rejected, got #{outcomes.inspect}"
      assert_equal 0, @user.reload.credit_balance
      assert_equal 1, CreditLedgerEntry.where(user_id: @user.id).import_spend.count
    end

    test "the balance can never go negative even under concurrency" do
      threads = 5.times.map do |i|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            Ledger.spend!(user: User.find(@user.id), idempotency_key: "race:#{i}")
          rescue InsufficientCredits
            nil
          end
        end
      end
      threads.each(&:join)

      assert_equal 0, @user.reload.credit_balance
      assert_operator @user.credit_balance, :>=, 0
    end
  end
end
