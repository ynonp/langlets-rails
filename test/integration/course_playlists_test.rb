require "test_helper"

class CoursePlaylistsTest < ActionDispatch::IntegrationTest
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
    @system_playlist = Playlist.create!(name: "Existing Playlist", published: true, slug: "existing-#{SecureRandom.hex(4)}")
  end

  def sign_in(user)
    post user_session_url, params: { user: { email: user.email, password: "password123" } }
  end

  test "show page renders the + button for an admin" do
    sign_in(@admin)
    get course_url(@course.slug)
    assert_response :success
    assert_select 'button[data-action="course-paths#open"]'
    assert_select '[data-controller="course-paths"]'
    assert_select 'form[data-action="submit->course-paths#submitCreate"]'
    assert_select 'input[data-course-paths-target="createName"]'
    assert_select 'button[data-action="course-paths#close"]', text: "Done", count: 1
    assert_select 'button[data-course-paths-target="newButton"]', text: "New Playlist"
    assert_select '[data-course-paths-target="searchContainer"] input[placeholder="Find a playlist"]'
    assert_select 'button[data-action="course-paths#close"]', text: "Cancel", count: 0
  end

  test "show page renders the + button for any signed-in user" do
    sign_in(@other)
    get course_url(@course.slug)
    assert_response :success
    assert_select 'button[data-action="course-paths#open"]'
  end

  test "native tab builds mark the layout and render a tab-safe playlist sheet" do
    sign_in(@other)
    get course_url(@course.slug, lang: "en"), headers: { "User-Agent" => "LangletsNative/2.0" }

    assert_response :success
    assert_select "body[data-native-tabs]"
    assert_select ".playlist-sheet-overlay .playlist-sheet"
  end

  test "show page hides the + button for anonymous users" do
    get course_url(@course.slug)
    assert_response :success
    assert_select 'button[data-action="course-paths#open"]', count: 0
  end

  test "index returns system playlists with membership flags for admin" do
    @course.playlists << @system_playlist
    sign_in(@admin)
    get course_playlists_url(@course.slug), headers: { "Accept" => "application/json" }
    assert_response :success
    body = JSON.parse(response.body)
    entry = body["paths"].find { |p| p["id"] == @system_playlist.id }
    assert entry["member"]
  end

  test "index for a regular user lists only their own playlists" do
    own = Playlist.create!(name: "Mine", published: true, slug: "mine-#{SecureRandom.hex(4)}", user: @other)
    foreign = Playlist.create!(name: "Not Mine", published: true, slug: "not-mine-#{SecureRandom.hex(4)}", user: @admin)

    sign_in(@other)
    get course_playlists_url(@course.slug), headers: { "Accept" => "application/json" }
    assert_response :success
    ids = JSON.parse(response.body)["paths"].map { |p| p["id"] }
    assert_includes ids, own.id
    assert_not_includes ids, @system_playlist.id
    assert_not_includes ids, foreign.id
  end

  test "admin create attaches an existing system playlist" do
    sign_in(@admin)
    assert_difference "CoursesPlaylist.count", 1 do
      post course_playlists_url(@course.slug),
        params: { playlist_id: @system_playlist.id }.to_json,
        headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    end
    assert_response :success
    assert JSON.parse(response.body)["path"]["member"]
    assert_includes @course.reload.playlists, @system_playlist
  end

  test "admin create builds a brand new system playlist" do
    sign_in(@admin)
    assert_difference [ "Playlist.count", "CoursesPlaylist.count" ], 1 do
      post course_playlists_url(@course.slug),
        params: { name: "Fresh Playlist" }.to_json,
        headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    end
    assert_response :success
    new_playlist = Playlist.find_by(name: "Fresh Playlist")
    assert new_playlist.published
    assert_nil new_playlist.user_id
    assert_includes @course.reload.playlists, new_playlist
  end

  test "regular user create builds a playlist they own" do
    sign_in(@other)
    assert_difference [ "Playlist.count", "CoursesPlaylist.count" ], 1 do
      post course_playlists_url(@course.slug),
        params: { name: "My Playlist" }.to_json,
        headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    end
    assert_response :success
    new_playlist = Playlist.find_by(name: "My Playlist")
    assert_equal @other.id, new_playlist.user_id
    assert_includes @course.reload.playlists, new_playlist
  end

  test "regular user can add someone else's course to their own playlist" do
    own = Playlist.create!(name: "Mine", published: true, slug: "mine-#{SecureRandom.hex(4)}", user: @other)
    sign_in(@other)
    assert_difference "CoursesPlaylist.count", 1 do
      post course_playlists_url(@course.slug),
        params: { playlist_id: own.id }.to_json,
        headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    end
    assert_response :success
    assert_includes @course.reload.playlists, own
  end

  test "regular user cannot modify a system playlist" do
    sign_in(@other)
    assert_raises(CanCan::AccessDenied) do
      post course_playlists_url(@course.slug),
        params: { playlist_id: @system_playlist.id }.to_json,
        headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    end
  end

  test "regular user cannot modify another user's playlist" do
    foreign = Playlist.create!(name: "Not Mine", published: true, slug: "not-mine-#{SecureRandom.hex(4)}", user: @admin)
    sign_in(@other)
    assert_raises(CanCan::AccessDenied) do
      post course_playlists_url(@course.slug),
        params: { playlist_id: foreign.id }.to_json,
        headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    end
  end

  test "destroy detaches a playlist the user owns" do
    own = Playlist.create!(name: "Mine", published: true, slug: "mine-#{SecureRandom.hex(4)}", user: @other)
    @course.playlists << own
    sign_in(@other)
    assert_difference "CoursesPlaylist.count", -1 do
      delete course_playlist_url(@course.slug, own.id),
        headers: { "Accept" => "application/json" }
    end
    assert_response :success
    assert_not_includes @course.reload.playlists, own
  end

  test "admin destroy detaches a system playlist" do
    @course.playlists << @system_playlist
    sign_in(@admin)
    assert_difference "CoursesPlaylist.count", -1 do
      delete course_playlist_url(@course.slug, @system_playlist.id),
        headers: { "Accept" => "application/json" }
    end
    assert_response :success
    assert_not_includes @course.reload.playlists, @system_playlist
  end
end
