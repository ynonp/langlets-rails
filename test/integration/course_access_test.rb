require "test_helper"

# Reading a Course is governed by Channel visibility, not by Course#status.
# Only Courses in a public Channel are readable by the world; everything else
# needs ownership, an accepted subscription, or admin.
class CourseAccessTest < ActionDispatch::IntegrationTest
  def setup
    @owner = User.create!(
      email: "course-access-owner@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @stranger = User.create!(
      email: "course-access-stranger@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @admin = User.create!(
      email: "ynon@hey.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @english = languages(:english)
    @medium = Medium.create!(url: "https://www.youtube.com/watch?v=accesstest", language: @english)

    @course = Course.create!(
      user: @owner,
      name: "Access Test Course",
      slug: "access-test-course",
      main_media_url: @medium.url,
      language: @english,
      status: :published
    )
    @lesson = Lesson.create!(
      course: @course, medium: @medium, user: @owner,
      name: "Access Lesson", slug: "access-lesson", order: 1
    )
    # A renderable activity: the lesson view reads the first phrase, so an
    # activity with no phrases would blow up before access control mattered.
    phrase = create_translated_phrase!(
      medium: @medium, l1: @english, l2: languages(:spanish),
      text_l1: "Hello world", text_l2: "Hola mundo", timestamp: "00:00:05"
    )
    activity = Activities::SpeakActivity.create!(lesson: @lesson, user: @owner, order: 1)
    activity.phrases << phrase
    @channel = @owner.provision_default_channel!
    @channel.publish!(@course)
  end

  def sign_in(user)
    post user_session_url, params: { user: { email: user.email, password: "password123" } }
  end

  # The sign-in redirect carries ?returnto= so the visitor lands back on the
  # course once they authenticate; assert on the path, not the query string.
  def assert_redirected_to_sign_in
    assert_response :redirect
    assert_equal new_user_session_path, URI.parse(response.location).path
  end

  # --- public channel: readable by the world ---

  test "a guest can read a course in a public channel" do
    @channel.update!(visibility: :public)

    get course_url(@course.slug)

    assert_response :success
  end

  test "a guest can read a lesson of a course in a public channel" do
    @channel.update!(visibility: :public)

    get course_lesson_url(@course.slug, @lesson.slug)

    assert_response :success
  end

  # --- private channel: not readable by the world ---

  test "a guest is sent to sign in for a course in a private channel" do
    @channel.update!(visibility: :private)

    get course_url(@course.slug)

    assert_redirected_to_sign_in
  end

  test "a guest is sent to sign in for a lesson in a private channel" do
    @channel.update!(visibility: :private)

    get course_lesson_url(@course.slug, @lesson.slug)

    assert_redirected_to_sign_in
  end

  test "a guest is sent to sign in for the full player of a private course" do
    @channel.update!(visibility: :private)
    @course.update!(show_full_course_player: true)

    get course_full_player_url(course_slug: @course.slug)

    assert_redirected_to_sign_in
  end

  test "signing in returns the visitor to the course they asked for" do
    @channel.update!(visibility: :private)

    get course_url(@course.slug)
    returnto = Rack::Utils.parse_query(URI.parse(response.location).query)["returnto"]

    post user_session_url, params: {
      user: { email: @owner.email, password: "password123" }, returnto: returnto
    }

    assert_redirected_to course_path(@course.slug)
  end

  # --- private channel: 404 for a signed-in stranger ---

  test "a signed-in stranger gets a 404 for a course in a private channel" do
    @channel.update!(visibility: :private)
    sign_in(@stranger)

    get course_url(@course.slug)

    assert_response :not_found
  end

  test "a signed-in stranger gets a 404 for a lesson in a private channel" do
    @channel.update!(visibility: :private)
    sign_in(@stranger)

    get course_lesson_url(@course.slug, @lesson.slug)

    assert_response :not_found
  end

  # --- owner, subscriber, admin ---

  test "the owner can read their own course in a private channel" do
    @channel.update!(visibility: :private)
    sign_in(@owner)

    get course_url(@course.slug)

    assert_response :success
  end

  test "a subscriber can read a course in a shared channel" do
    @channel.update!(visibility: :shared)
    ChannelSubscription.create!(channel: @channel, user: @stranger)
    sign_in(@stranger)

    get course_url(@course.slug)

    assert_response :success
  end

  test "a non-subscriber cannot read a course in a shared channel" do
    @channel.update!(visibility: :shared)
    sign_in(@stranger)

    get course_url(@course.slug)

    assert_response :not_found
  end

  test "an admin can read a course in someone else's private channel" do
    @channel.update!(visibility: :private)
    sign_in(@admin)

    get course_url(@course.slug)

    assert_response :success
  end

  # --- unpublishing revokes access ---

  test "removing the course from every channel revokes access" do
    @channel.update!(visibility: :public)
    @channel.unpublish!(@course)

    get course_url(@course.slug)

    assert_redirected_to_sign_in
  end

  # --- listing surfaces ---

  test "a private course is not listed on the homepage for a guest" do
    @channel.update!(visibility: :private)

    get root_path

    assert_response :success
    assert_select ".lp-card-title", text: /Access Test Course/, count: 0
  end

  test "a private course is not listed on a playlist page for a guest" do
    @channel.update!(visibility: :private)
    playlist = Playlist.create!(name: "Access Playlist", published: true, slug: "access-playlist")
    playlist.courses << @course

    get playlist_url(playlist)

    assert_response :success
    assert_select "body", text: /Access Test Course/, count: 0
  end

  test "a stranger cannot enroll in a course they cannot read" do
    @channel.update!(visibility: :private)
    sign_in(@stranger)

    post app_enrollments_url(lang: "en"), params: { course_slug: @course.slug },
         headers: { "User-Agent" => "LangletsNative/1.0" }

    assert_response :not_found
  end

  test "a stranger cannot add a course they cannot read to their playlist" do
    @channel.update!(visibility: :private)
    sign_in(@stranger)

    post course_playlists_url(course_id: @course.slug), params: { name: "Mine" }

    assert_response :not_found
  end
end
