require "test_helper"

class UserOauthTest < ActiveSupport::TestCase
  AuthInfo = Data.define(:email)
  AuthHash = Data.define(:provider, :uid, :info)

  test "OAuth confirms an existing unconfirmed account for every provider" do
    %w[google_oauth2 github apple].each do |provider|
      email = "#{provider}@example.com"
      user = User.create!(email: email, password: "password123")
      assert_not user.confirmed?, "expected #{provider} fixture to start unconfirmed"

      linked_user = User.from_omniauth(
        AuthHash.new(provider: provider, uid: "#{provider}-uid", info: AuthInfo.new(email: email))
      )

      assert_predicate linked_user, :confirmed?, "expected #{provider} OAuth to confirm the account"
      assert_predicate linked_user, :active_for_authentication?
      assert_equal provider, linked_user.provider
      assert_equal "#{provider}-uid", linked_user.uid
    end
  end
end
