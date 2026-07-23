require "test_helper"

# The public homepage no longer lists playlists (it shows a flat grid of course
# cards). The ownership rule those homepage tests used to exercise lives in
# Playlist.visible_to, so it's tested directly here — system playlists are
# visible to everyone, personal playlists only to their owner.
class PlaylistsVisibilityTest < ActiveSupport::TestCase
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

  test "anonymous visitors see system playlists but no personal ones" do
    visible = Playlist.visible_to(nil)
    assert_includes visible, @system_playlist
    assert_not_includes visible, @own_playlist
  end

  test "owner sees their own playlists alongside system playlists" do
    visible = Playlist.visible_to(@user)
    assert_includes visible, @system_playlist
    assert_includes visible, @own_playlist
  end

  test "other users do not see someone else's personal playlists" do
    visible = Playlist.visible_to(@stranger)
    assert_includes visible, @system_playlist
    assert_not_includes visible, @own_playlist
  end
end
