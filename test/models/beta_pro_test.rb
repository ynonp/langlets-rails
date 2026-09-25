require "test_helper"

class BetaProTest < ActiveSupport::TestCase
  test "beta gives existing and new accounts Pro without creating subscriptions" do
    existing = User.create!(email: "existing-beta@example.test", password: "password123")
    assert_not existing.pro?
    Rails.configuration.x.stub(:beta_pro, true) do
      assert User.beta_pro?
      assert existing.pro?, "even an instance with a cached non-Pro answer"
      newcomer = User.create!(email: "new-beta@example.test", password: "password123")
      assert newcomer.pro?
      assert_empty newcomer.subscriptions
      assert_empty existing.subscriptions
    end
    assert_not existing.pro?, "beta access ends when the setting is disabled"
  end

  test "ending beta preserves explicit Pro grants" do
    user = User.create!(email: "granted-beta@example.test", password: "password123")
    user.pro!
    User.stub(:beta_pro?, true) { assert user.pro? }
    assert user.reload.pro?
  end
end
