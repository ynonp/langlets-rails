require "test_helper"

class DeviceTokenTest < ActiveSupport::TestCase
  TOKEN = "a" * 64

  setup do
    @user = User.create!(email: "device@example.com", password: "password123", confirmed_at: Time.zone.now)
    @other = User.create!(email: "device2@example.com", password: "password123", confirmed_at: Time.zone.now)
  end

  test "registering stores the device against the user" do
    device = DeviceToken.register!(user: @user, token: TOKEN, environment: "sandbox", app_version: "2.0")

    assert_equal @user, device.user
    assert_equal "sandbox", device.environment
    assert_equal "2.0", device.app_version
    assert device.active?
    assert_not_nil device.last_seen_at
  end

  test "re-registering the same device updates rather than duplicating" do
    first = DeviceToken.register!(user: @user, token: TOKEN)
    second = DeviceToken.register!(user: @user, token: TOKEN, app_version: "2.1")

    assert_equal first.id, second.id
    assert_equal 1, DeviceToken.count
    assert_equal "2.1", second.app_version
  end

  # The reason `token` is unique globally rather than per user. A phone can change
  # hands: sign out, someone else signs in. If both rows survived we'd push user
  # A's course titles to a device now held by user B.
  test "a device that changes hands moves to the new user" do
    DeviceToken.register!(user: @user, token: TOKEN)

    DeviceToken.register!(user: @other, token: TOKEN)

    assert_equal 1, DeviceToken.count
    assert_equal @other, DeviceToken.sole.user
    assert_empty @user.device_tokens.reload
  end

  test "the same token cannot be inserted twice" do
    DeviceToken.create!(user: @user, token: TOKEN)

    assert_raises(ActiveRecord::RecordNotUnique) do
      DeviceToken.insert!({ user_id: @other.id, token: TOKEN, platform: 0, environment: "production",
                            created_at: Time.zone.now, updated_at: Time.zone.now })
    end
  end

  test "invalidating keeps the row so the history survives" do
    device = DeviceToken.register!(user: @user, token: TOKEN)

    device.invalidate!

    assert_not device.reload.active?
    assert_not_nil device.invalidated_at
    assert_equal 1, DeviceToken.count, "invalidating must not delete"
    assert_empty @user.device_tokens.active
  end

  # iOS only hands the token back when the install can actually receive push, so
  # re-registration is a reliable signal that Apple's earlier 410 is stale.
  test "re-registering revives an invalidated device" do
    device = DeviceToken.register!(user: @user, token: TOKEN)
    device.invalidate!

    DeviceToken.register!(user: @user, token: TOKEN)

    assert device.reload.active?
  end

  test "environment must be one Apple actually has" do
    device = DeviceToken.new(user: @user, token: TOKEN, environment: "staging")

    assert_not device.valid?
    assert_includes device.errors[:environment], "is not included in the list"
  end

  test "deleting a user takes their devices" do
    DeviceToken.register!(user: @user, token: TOKEN)

    @user.destroy

    assert_equal 0, DeviceToken.count
  end
end
