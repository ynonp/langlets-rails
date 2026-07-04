require "test_helper"

class Settings::ConnectionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "connections@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @other_user = User.create!(
      email: "other-connections@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    @application = create_oauth_app(name: "Claude")
    @token = create_access_token(@user, application: @application)
    @other_token = create_access_token(@other_user, application: @application)
  end

  def sign_in(user)
    post user_session_url, params: { user: { email: user.email, password: "password123" } }
  end

  test "requires sign in" do
    get settings_connections_url

    assert_redirected_to new_user_session_path
  end

  test "lists only the current user's active tokens" do
    revoked = create_access_token(@user, application: @application)
    revoked.revoke
    expired = create_access_token(@user, application: @application)
    expired.update_column(:created_at, 3.hours.ago)

    sign_in(@user)
    get settings_connections_url

    assert_response :success
    assert_includes @response.body, "Claude"
    assert_includes @response.body, "1 active token"
    assert_includes @response.body, "vocabulary:read"
  end

  test "revokes a single token" do
    sign_in(@user)

    delete settings_connection_url(@token)

    assert_redirected_to settings_connections_path
    assert @token.reload.revoked_at.present?
    assert_nil @other_token.reload.revoked_at
  end

  test "cannot revoke another user's token" do
    sign_in(@user)

    delete settings_connection_url(@other_token)

    assert_response :not_found
    assert_nil @other_token.reload.revoked_at
  end

  test "disconnecting an application revokes all of the user's tokens for it" do
    second_token = create_access_token(@user, application: @application)

    sign_in(@user)
    delete revoke_application_settings_connections_url(application_id: @application.id)

    assert_redirected_to settings_connections_path
    assert @token.reload.revoked_at.present?
    assert second_token.reload.revoked_at.present?
    assert_nil @other_token.reload.revoked_at
  end
end
