require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "pro@example.com", password: "password123", confirmed_at: Time.zone.now)
  end

  test "an active subscription in its window entitles Pro" do
    subscribe!(expires_at: 30.days.from_now)

    assert @user.pro?
    assert @user.pro_subscription
  end

  test "an active subscription past its expiry does not entitle Pro" do
    # The status column lags reality between App Store notifications, so
    # expires_at is what decides — otherwise every subscriber would keep Pro
    # forever the moment a DID_RENEW notification went missing.
    subscribe!(expires_at: 1.hour.ago)

    assert_not @user.pro?
    assert_nil @user.pro_subscription
  end

  test "a revoked subscription does not entitle Pro even before its expiry" do
    subscribe!(expires_at: 30.days.from_now, status: :revoked)

    assert_not @user.pro?
  end

  test "a lapsed subscription does not cancel out a current one" do
    subscribe!(expires_at: 2.months.ago, status: :expired, original_transaction_id: "old")
    subscribe!(expires_at: 30.days.from_now, original_transaction_id: "current")

    assert @user.pro?
    assert_equal "current", @user.pro_subscription.original_transaction_id
  end

  test "pro? is memoised per instance and cleared by reload" do
    assert_not @user.pro?

    subscribe!(expires_at: 30.days.from_now)
    assert_not @user.pro?, "an in-memory user keeps the answer it already gave"
    assert @user.reload.pro?
  end

  # Both of these drive what the Home upsell card and the paywall's opening line
  # say, and both are the kind of arithmetic that regresses quietly.
  test "free_imports_used counts spends and clamps to the signup grant" do
    assert_equal 0, @user.free_imports_used

    spend!(2)
    assert_equal 2, @user.free_imports_used

    # Buying a pack and spending it pushes the raw count past the grant. "You've
    # used 5 of 3 free imports" is nonsense, so it clamps.
    Credits::Ledger.grant!(user: @user, amount: 20, reason: :iap_purchase, idempotency_key: "pack:1")
    spend!(3)
    assert_equal 5, @user.credit_ledger_entries.import_spend.count
    assert_equal User::SIGNUP_CREDITS, @user.free_imports_used
  end

  test "purchased_credits? flips once a pack is bought, and drives the card's copy" do
    assert_not @user.purchased_credits?, "the signup grant is not a purchase"

    spend!(1)
    assert_not @user.purchased_credits?

    Credits::Ledger.grant!(user: @user, amount: 20, reason: :iap_purchase, idempotency_key: "pack:2")
    assert @user.purchased_credits?
  end

  private

  def spend!(count)
    count.times do |i|
      Credits::Ledger.spend!(user: @user, idempotency_key: "spend:#{@user.id}:#{SecureRandom.hex(4)}:#{i}")
    end
  end

  def subscribe!(expires_at:, status: :active, original_transaction_id: "2000000000000001")
    Subscription.create!(
      user: @user,
      product_id: Apple::SubscriptionPlans.yearly.product_id,
      plan: :yearly,
      status: status,
      original_transaction_id: original_transaction_id,
      purchased_at: 1.day.ago,
      expires_at: expires_at
    )
  end
end
