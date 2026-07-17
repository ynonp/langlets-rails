require "test_helper"

class PlaylistsDestroyTest < ActionDispatch::IntegrationTest
  def setup
    @admin = User.create!(
      email: "ynon@hey.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @other = User.create!(
      email: "someone@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @course = Course.create!(
      user: @admin,
      name: "Test Course #{SecureRandom.hex(4)}",
      slug: "test-course-#{SecureRandom.hex(4)}",
      main_media_url: "https://www.youtube.com/watch?v=abc123",
      status: :published
    )
    @playlist = Playlist.create!(name: "Deletable Playlist", published: true, slug: "deletable-#{SecureRandom.hex(4)}")
    @playlist.courses << @course
  end

  def sign_in(user)
    post user_session_url, params: { user: { email: user.email, password: "password123" } }
  end

  test "show page renders the Delete button for an admin" do
    sign_in(@admin)
    get playlist_url(@playlist)
    assert_response :success
    assert_select "form[action=?][method=post] button", playlist_path(@playlist)
    assert_select "button", text: /Delete/
    assert_select '[data-playlist-courses-target="deleteOverlay"].playlist-sheet-overlay'
    assert_select '[data-playlist-courses-target="deleteOverlay"] .playlist-sheet'
    assert_select 'form[data-turbo-confirm]', count: 0
  end

  test "show page hides the Delete button for a regular user on a system playlist" do
    sign_in(@other)
    get playlist_url(@playlist)
    assert_response :success
    assert_select "form[action=?]", playlist_path(@playlist), count: 0
  end

  test "show page hides the Delete button for anonymous users" do
    get playlist_url(@playlist)
    assert_response :success
    assert_select "form[action=?]", playlist_path(@playlist), count: 0
  end

  test "show page renders the Delete button for the playlist's owner" do
    own = Playlist.create!(name: "My Playlist", published: true, slug: "my-playlist-#{SecureRandom.hex(4)}", user: @other)
    sign_in(@other)
    get playlist_url(own)
    assert_response :success
    assert_select "form[action=?][method=post] button", playlist_path(own)
  end

  test "personal playlists are hidden from other users" do
    own = Playlist.create!(name: "My Playlist", published: true, slug: "my-playlist-#{SecureRandom.hex(4)}", user: @other)

    sign_in(@admin) # admins can moderate, so use a third perspective below
    get playlist_url(own)
    assert_response :success

    delete destroy_user_session_url
    get playlist_url(own)
    assert_response :not_found
  end

  test "admin can delete a system playlist without destroying its courses" do
    sign_in(@admin)
    assert_difference "Playlist.count", -1 do
      assert_no_difference "Course.count" do
        delete playlist_url(@playlist)
      end
    end
    assert_redirected_to root_path
    assert Course.exists?(@course.id)
  end

  test "owner can delete their own playlist" do
    own = Playlist.create!(name: "My Playlist", published: true, slug: "my-playlist-#{SecureRandom.hex(4)}", user: @other)
    own.courses << @course

    sign_in(@other)
    assert_difference "Playlist.count", -1 do
      assert_no_difference "Course.count" do
        delete playlist_url(own)
      end
    end
    assert_redirected_to root_path
  end

  test "regular user is forbidden from deleting a system playlist" do
    sign_in(@other)
    assert_raises(CanCan::AccessDenied) do
      delete playlist_url(@playlist)
    end
    assert Playlist.exists?(@playlist.id)
  end

  test "user cannot delete another user's playlist" do
    third = User.create!(
      email: "third@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    own = Playlist.create!(name: "My Playlist", published: true, slug: "my-playlist-#{SecureRandom.hex(4)}", user: @other)

    sign_in(third)
    delete playlist_url(own)
    assert_response :not_found
    assert Playlist.exists?(own.id)
  end

  test "anonymous users are redirected when attempting to delete" do
    delete playlist_url(@playlist)
    assert_redirected_to new_user_session_path
    assert Playlist.exists?(@playlist.id)
  end
end
