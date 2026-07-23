require "test_helper"

module Paypal
  class ProcessNotificationTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(
        email: "paypal-ipn@example.com",
        password: "password123",
        confirmed_at: Time.zone.now
      )
      @client = Client.new(merchant_id: "MERCHANT123")
      @pack = CreditPacks.fetch("starter")
      @token = @client.purchase_token(user: @user, pack: @pack)
      @client.define_singleton_method(:verify_ipn) { |_raw_body| true }
    end

    test "a verified completed payment grants its fixed credit pack" do
      result = process

      assert_equal :credited, result.status
      assert_equal 8, @user.reload.credit_balance
      assert result.ledger_entry.iap_purchase?
      assert_equal "paypal:PAYPAL-TXN-1", result.ledger_entry.idempotency_key
      assert_equal "starter", result.ledger_entry.metadata["pack_id"]
    end

    test "a duplicate IPN credits the transaction only once" do
      first = process
      second = process

      assert_equal first.ledger_entry.id, second.ledger_entry.id
      assert_equal 8, @user.reload.credit_balance
      assert_equal 1, @user.credit_ledger_entries.iap_purchase.count
    end

    test "an unverified notification is rejected" do
      @client.define_singleton_method(:verify_ipn) { |_raw_body| false }

      assert_equal :invalid, process.status
      assert_equal 3, @user.reload.credit_balance
    end

    test "pending payments are ignored until PayPal sends Completed" do
      assert_equal :ignored, process(payment_status: "Pending").status
      assert_equal 3, @user.reload.credit_balance
    end

    test "wrong merchant amount currency item or signed token never credits" do
      invalid_changes = [
        { receiver_id: "ATTACKER" },
        { mc_gross: "0.01" },
        { mc_currency: "EUR" },
        { item_number: "credits_40" },
        { custom: "#{@token}tampered" }
      ]

      invalid_changes.each do |changes|
        assert_equal :invalid, process(**changes).status, changes.inspect
      end
      assert_equal 3, @user.reload.credit_balance
    end

    private

    def process(**changes)
      attributes = {
        payment_status: "Completed",
        receiver_id: "MERCHANT123",
        txn_id: "PAYPAL-TXN-1",
        item_number: @pack.item_number,
        mc_gross: @pack.price,
        mc_currency: "USD",
        custom: @token,
        payer_id: "SANDBOXBUYER"
      }.merge(changes)

      ProcessNotification.call(raw_body: URI.encode_www_form(attributes), client: @client)
    end
  end
end
