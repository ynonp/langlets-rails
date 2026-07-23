require "test_helper"
require "minitest/mock"

module Paypal
  class ClientTest < ActiveSupport::TestCase
    setup do
      @client = Client.new(merchant_id: "SANDBOXMERCHANT")
      @user = User.create!(
        email: "paypal-client@example.com",
        password: "password123",
        confirmed_at: Time.zone.now
      )
    end

    test "non-production environments use the PayPal sandbox" do
      assert_equal Client::SANDBOX_URL, @client.checkout_url
    end

    test "purchase tokens bind a user to a server-defined pack" do
      pack = CreditPacks.fetch("popular")
      token = @client.purchase_token(user: @user, pack:)

      assert_equal(
        { "user_id" => @user.id, "pack_id" => "popular" },
        @client.decode_purchase_token(token).to_h.stringify_keys
      )
      assert_nil @client.decode_purchase_token("#{token}tampered")
    end

    test "IPN verification posts the exact payload back to PayPal" do
      response = Struct.new(:body) do
        def code = "200"
        def is_a?(klass) = klass == Net::HTTPSuccess
      end.new("VERIFIED")
      captured_request = nil

      Net::HTTP.stub(:start, ->(*_args, **_options, &block) {
        http = Object.new
        http.define_singleton_method(:request) do |request|
          captured_request = request
          response
        end
        block.call(http)
      }) do
        assert @client.verify_ipn("txn_id=ABC&mc_gross=2.99")
      end

      assert_equal "cmd=_notify-validate&txn_id=ABC&mc_gross=2.99", captured_request.body
    end
  end
end
