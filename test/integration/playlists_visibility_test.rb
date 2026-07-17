require "test_helper"

class PlaylistsVisibilityTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "someone@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @stranger = User.create!(
      email: "stranger@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @system_playlist = Playlist.create!(name: "System Playlist", published: true, slug: "system-#{SecureRandom.hex(4)}")
    @own_playlist = Playlist.create!(name: "Personal Playlist", published: true, slug: "personal-#{SecureRandom.hex(4)}", user: @user)
  end

  def sign_in(user)
    post user_session_url, params: { user: { email: user.email, password: "password123" } }
  end

  test "anonymous visitors see system playlists but no personal ones" do
    get root_path
    assert_response :success
    assert_select "[data-testid='tabs-panel-courses']", text: /System Playlist/
    assert_select "[data-testid='tabs-panel-courses']", text: /Personal Playlist/, count: 0
  end

  test "owner sees their own playlists alongside system playlists" do
    sign_in(@user)
    get root_path
    assert_response :success
    assert_select "[data-testid='tabs-panel-courses']", text: /System Playlist/
    assert_select "[data-testid='tabs-panel-courses']", text: /Personal Playlist/
  end

  test "other users do not see someone else's playlists" do
    sign_in(@stranger)
    get root_path
    assert_response :success
    assert_select "[data-testid='tabs-panel-courses']", text: /Personal Playlist/, count: 0
  end
end
