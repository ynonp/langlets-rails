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

  test "profile renders the XP chart, language picker, theme toggle and delete button" do
    sign_in_as @user
    ActivityLog.log_activity_completion(user: @user, active_time: 60, xp_gained: 30)

    get profile_path

    assert_response :success
    assert_select "h1", text: "Profile"
    assert_select "h2", text: "XP this week"
    assert_select "h2", text: "Learning language"
    assert_select "h2", text: "Theme"
    assert_select "h2", text: "Delete my account"
    # The delete button posts to Devise's registrations#destroy.
    assert_select "form[action=?][method=post]", user_registration_path
    # The way out sits between the settings and the delete section.
    assert_select "a[href=?]", root_path, text: "Continue Learning"
  end

  test "web profile shows a language select defaulting to all content" do
    language = Language.first || Language.create!(iso_name: "es", english_name: "Spanish", native_name: "Español")
    sign_in_as @user

    get profile_path

    assert_select "select[data-controller=?]", "language-select"
    assert_select "select option[selected]", text: /Show All Content/
    assert_select "select option", text: /#{language.english_name}/
    # The native-only bridge buttons stay off the web page.
    assert_select "[data-controller=?]", "bridge--language-selection", count: 0
  end

  test "selecting a language keeps lang on generated urls, and all content clears it" do
    language = Language.first || Language.create!(iso_name: "es", english_name: "Spanish", native_name: "Español")
    sign_in_as @user

    get profile_path(lang: language.iso_name)
    assert_equal language.iso_name, session[:lang]

    # Subsequent requests without the param stay in that language.
    get profile_path
    assert_select "option[selected]", text: /#{language.english_name}/

    get profile_path(lang: "all")
    assert_nil session[:lang]
    assert_select "option[selected]", text: /Show All Content/
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
