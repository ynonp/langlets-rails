require "test_helper"

class SignOutFlowTest < ActionDispatch::IntegrationTest
  NATIVE = { "User-Agent" => "LangletsNative" }.freeze

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

  # Native flows. The signed_out marker must land on a page that actually
  # renders — every app screen redirects a signed-out native user to sign-in,
  # which would silently drop the marker (and the native wipe) if the redirect
  # went anywhere else. And the language must not survive sign-out: it belongs
  # to the account that left, and a carried-over ?lang= skips onboarding for
  # the next account.
  test "native sign-out goes straight to sign-in without the language" do
    sign_in_as @user
    get "/app?lang=es", headers: NATIVE

    delete destroy_user_session_path(returnto: "/app?lang=es"), headers: NATIVE

    # Literal path: the route helper would re-add ?lang= from this test
    # session's default_url_options — the absence of lang is the point.
    assert_redirected_to "/users/sign_in?signed_out=1"
    follow_redirect!(headers: NATIVE.dup)

    assert_response :success
    assert_select "div[data-controller=?]", "bridge--sign-out"
  end

  test "native sign-in restores the account language without onboarding" do
    sign_in_as @user
    get "/app?lang=es", headers: NATIVE
    assert_equal "es", @user.reload.ios_lang

    delete destroy_user_session_path, headers: NATIVE
    follow_redirect!(headers: NATIVE.dup)

    post user_session_path(returnto: "/app"),
         params: { user: { email: @user.email, password: "password123" } },
         headers: NATIVE

    assert_redirected_to "/app?lang=es&ios_lang=es"
    follow_redirect!(headers: NATIVE.dup)
    assert_response :success
  end

  test "deleting the account does not leak the language into the next account" do
    sign_in_as @user
    get "/app?lang=es", headers: NATIVE

    delete user_registration_path, headers: NATIVE

    assert_redirected_to "/users/sign_in?signed_out=1"
    follow_redirect!(headers: NATIVE.dup)
    assert_select "div[data-controller=?]", "bridge--sign-out"

    fresh = User.create!(email: "fresh-account@example.com", password: "password123",
                         confirmed_at: Time.zone.now)
    sign_in_as fresh

    get "/app", headers: NATIVE
    assert_redirected_to onboarding_welcome_path(returnto: "/app")
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
