require "test_helper"

# The delivery preference: which of email and push a notification goes out over.
class ProfileNotificationsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    Rails.application.reload_routes_unless_loaded
    @user = User.create!(email: "profile-notify@example.com", password: "password123", confirmed_at: Time.zone.now)
    sign_in @user
  end

  test "an account receives both channels until it says otherwise" do
    assert_equal %w[email push], @user.notification_delivery
    assert @user.email_notifications?
    assert @user.push_notifications?
  end

  test "the profile page offers a box per channel" do
    get profile_path

    assert_response :success
    assert_select "form[action=?]", profile_notifications_path
    assert_select "input[type=checkbox][name=?]", "user[notification_delivery][]", count: 2
    assert_select "input[type=checkbox][name=?][checked=checked]", "user[notification_delivery][]", count: 2
  end

  test "choosing email only" do
    patch profile_notifications_path, params: { user: { notification_delivery: [ "", "email" ] } }

    assert_redirected_to profile_path
    assert_equal [ "email" ], @user.reload.notification_delivery
    assert_not @user.push_notifications?
  end

  # The one preference that looks like nothing was submitted. It has to stick:
  # the notification is still recorded on /notifications, which is what makes
  # turning every channel off safe to offer.
  test "turning both channels off" do
    patch profile_notifications_path, params: { user: { notification_delivery: [ "" ] } }

    assert_redirected_to profile_path
    assert_equal [], @user.reload.notification_delivery
    assert_not @user.email_notifications?
    assert_not @user.push_notifications?
  end

  # The channels are a fixed set; anything else is dropped rather than persisted
  # as a value the delivery job doesn't know how to read.
  test "an unknown channel is ignored" do
    patch profile_notifications_path, params: { user: { notification_delivery: [ "email", "carrier-pigeon" ] } }

    assert_equal [ "email" ], @user.reload.notification_delivery
  end

  # Order and duplicates come from whatever posted the form; what's stored is
  # canonical either way.
  test "the stored list is canonical" do
    patch profile_notifications_path, params: { user: { notification_delivery: [ "push", "email", "push" ] } }

    assert_equal %w[email push], @user.reload.notification_delivery
  end

  # Turning a channel off must not silence Devise or Channel invitations —
  # those are answers to something the user just did.
  test "the preference does not reach transactional mail" do
    @user.update!(notification_delivery: [])

    assert_emails 1 do
      @user.send_reset_password_instructions
    end
  end
end
