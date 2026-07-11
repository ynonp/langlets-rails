require "test_helper"

class SignOutFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "signout-test@example.com",
      password: "password123",
      confirmed_at: Time.current
    )
  end

  test "sign out redirects to root with the signed_out marker" do
    sign_in_as @user

    delete destroy_user_session_path

    assert_redirected_to "#{root_path}?signed_out=1"
  end

  test "sign out preserves returnto and appends the signed_out marker" do
    sign_in_as @user

    delete destroy_user_session_path(returnto: "/courses?lang=es")

    assert_redirected_to "/courses?lang=es&signed_out=1"
  end

  test "post-sign-out page renders the native sign-out bridge trigger" do
    sign_in_as @user

    delete destroy_user_session_path
    follow_redirect!

    assert_response :success
    assert_select "div[data-controller=?]", "bridge--sign-out"
  end

  test "regular pages do not render the sign-out bridge trigger" do
    get root_path

    assert_response :success
    assert_select "div[data-controller=?]", "bridge--sign-out", count: 0
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    follow_redirect!
  end
end
