require "test_helper"

class ProfileTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "profile-test@example.com",
      password: "password123",
      confirmed_at: Time.current
    )
  end

  test "profile requires a signed-in user" do
    get profile_path

    assert_redirected_to new_user_session_path
  end

  test "profile renders the XP chart, theme toggle and delete button" do
    sign_in_as @user
    ActivityLog.log_activity_completion(user: @user, active_time: 60, xp_gained: 30)

    get profile_path

    assert_response :success
    assert_select "h1", text: "Profile"
    assert_select "h2", text: "XP this week"
    assert_select "h2", text: "Learning language", count: 0
    assert_select "h2", text: "Theme"
    assert_select "h2", text: "Delete my account"
    # The delete button posts to Devise's registrations#destroy.
    assert_select "form[action=?][method=post]", user_registration_path
    # The way out sits between the settings and the delete section.
    assert_select "a[href=?]", root_path, text: "Continue Learning"
  end

  test "native profile offers and persists a native language" do
    sign_in_as @user

    get profile_path, headers: { "User-Agent" => "LangletsNative" }

    assert_response :success
    assert_select "form[action=?][data-controller=native-language][data-turbo=false]", profile_native_language_path
    assert_select "select[name=?]", "user[native_language]"
    assert_select "option[value=en][selected=selected]"
    assert_select "option[value=he]"
    assert_select "option", count: 2
    assert_select "input[type=submit][disabled=disabled]"
    assert_select "body[data-native-tabs] .profile-safe-area", count: 1

    patch profile_native_language_path,
      params: { user: { native_language: "he" } },
      headers: { "User-Agent" => "LangletsNative" }

    assert_redirected_to profile_path
    assert_equal "he", @user.reload.preferences["native_language"]
  end

  test "native profile rejects languages outside English and Hebrew" do
    sign_in_as @user

    patch profile_native_language_path,
      params: { user: { native_language: "fr" } },
      headers: { "User-Agent" => "LangletsNative" }

    assert_redirected_to profile_path
    assert_equal "Choose a supported language.", flash[:alert]
    assert_nil @user.reload.preferences["native_language"]
  end

  test "native profile uses the persisted language for all UI" do
    @user.update!(preferences: @user.preferences.merge("native_language" => "he"))
    sign_in_as @user

    get profile_path, headers: { "User-Agent" => "LangletsNative" }

    assert_response :success
    assert_select "h1", text: I18n.t("shared.menu.profile", locale: :he)
    assert_select "html[lang=he][dir=rtl]"
  end

  test "web profile does not offer the native language setting" do
    sign_in_as @user

    get profile_path

    assert_select "form[action=?]", profile_native_language_path, count: 0
  end

  test "web profile does not show the account card" do
    sign_in_as @user

    get profile_path

    assert_select "h2", text: "Account", count: 0
    assert_select "a", text: "Upgrade to Pro for unlimited imports", count: 0
  end

  test "native profile shows a free account with an upgrade button" do
    sign_in_as @user

    get profile_path, headers: { "User-Agent" => "LangletsNative" }

    assert_response :success
    assert_select "h2", text: "Account"
    assert_select "span", text: "Free"
    assert_select "a[href=?]", app_pro_path, text: "Upgrade to Pro for unlimited imports"
  end

  test "native profile shows a Pro account without the upgrade button" do
    @user.subscriptions.create!(
      product_id: Apple::SubscriptionPlans.yearly.product_id,
      original_transaction_id: "2000000555555555",
      status: :active,
      purchased_at: Time.zone.now,
      expires_at: 1.year.from_now
    )
    sign_in_as @user

    get profile_path, headers: { "User-Agent" => "LangletsNative" }

    assert_response :success
    assert_select "h2", text: "Account"
    assert_select "span", text: "Pro"
    assert_select "a", text: "Upgrade to Pro for unlimited imports", count: 0
  end

  test "native profile initially shows only the notification permission action" do
    sign_in_as @user

    get profile_path, headers: { "User-Agent" => "LangletsNative" }

    assert_select "[data-controller=?]", "bridge--notification-preference", count: 1
    assert_select "button[data-bridge--notification-preference-target=?]",
      "button", text: "Enable Notifications", count: 1
    assert_select "label[data-bridge--notification-preference-target=?][style=?]",
      "switch", "display: none", count: 1
  end

  # Every string on this page comes from the locale files, which is only
  # provable in a second locale: a key that exists in English and nowhere else
  # renders as Rails' "translation missing" here.
  test "the profile page renders in Hebrew" do
    Language.find_by(iso_name: "he") ||
      Language.create!(iso_name: "he", english_name: "Hebrew", native_name: "עברית")
    sign_in_as @user
    ActivityLog.log_activity_completion(user: @user, active_time: 60, xp_gained: 30)

    host! "he.example.com"
    get profile_path

    assert_response :success
    assert_select "h2", text: I18n.t("profile.xp.heading", locale: :he)
    assert_select "h2", text: I18n.t("profile.delete.heading", locale: :he)
    assert_select "a", text: I18n.t("profile.continue", locale: :he)
    assert_no_match(/translation missing/, response.body)
  end

  test "profile renders for a user with no activity at all" do
    sign_in_as @user

    get profile_path

    assert_response :success
    assert_select "h2", text: "XP this week"
  end

  test "xp series covers seven days and totals today's xp" do
    ActivityLog.log_activity_completion(user: @user, active_time: 60, xp_gained: 30)
    ActivityLog.log_activity_completion(user: @user, active_time: 60, xp_gained: 12)

    series = ActivityLog.daily_xp_series_for_user(@user, days: 7)

    assert_equal 7, series.size
    assert_equal Time.zone.now.to_date, series.last[:date]
    assert_equal 42, series.last[:xp]
    assert_equal 0, series.first[:xp]
  end

  test "xp series buckets an older log into its own day" do
    travel_to 3.days.ago do
      ActivityLog.log_activity_completion(user: @user, active_time: 60, xp_gained: 25)
    end

    series = ActivityLog.daily_xp_series_for_user(@user, days: 7)
    older = series.find { |day| day[:date] == 3.days.ago.to_date }

    assert_equal 25, older[:xp]
    assert_equal 0, series.last[:xp]
  end

  test "deleting the account removes the user and its dependent records" do
    sign_in_as @user
    UserGameStat.for_user(@user).add_xp(50)
    ActivityLog.log_activity_completion(user: @user, active_time: 60, xp_gained: 20)
    id = @user.id

    assert_difference "User.count", -1 do
      delete user_registration_path
    end

    assert_equal 0, UserGameStat.where(user_id: id).count
    assert_equal 0, ActivityLog.where(user_id: id).count
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    follow_redirect!
  end
end
