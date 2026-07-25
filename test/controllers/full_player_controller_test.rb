require "test_helper"

class FullPlayerControllerTest < ActionDispatch::IntegrationTest
  setup do
    @english = languages(:english)
    @user = User.create!(
      email: "full-player@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @medium = Medium.create!(
      url: "https://www.youtube.com/watch?v=abcdefghijk",
      language: @english
    )
    @course = Course.create!(
      name: "Full Player Test",
      slug: "full-player-test",
      main_media_url: @medium.url,
      language: @english,
      user: @user
    )
    Lesson.create!(
      course: @course,
      medium: @medium,
      user: @user,
      name: "Lesson",
      slug: "lesson",
      order: 1
    )
  end

  test "should route to full player page" do
    assert_routing(
      { path: "/courses/test-course/full-player", method: :get },
      { controller: "full_player", action: "show", course_slug: "test-course" }
    )
  end

  test "plays through the final token end timestamp" do
    phrase = create_translated_phrase!(
      medium: @medium,
      l1: @english,
      l2: @english,
      text_l1: "Money",
      text_l2: "Money",
      timestamp: "02:08.76"
    )
    phrase.phrase_tokens.create!(
      l1_start_index: 0,
      l1_end_index: 0,
      start_timestamp: "02:09.24",
      end_timestamp: "02:09.76"
    )

    get course_full_player_path(@course)

    assert_response :success
    assert_select "[data-segment-end='129.76']"
  end

  test "falls back to the final phrase timestamp without token timing" do
    create_translated_phrase!(
      medium: @medium,
      l1: @english,
      l2: @english,
      text_l1: "Money",
      text_l2: "Money",
      timestamp: "02:08.76"
    )

    get course_full_player_path(@course)

    assert_response :success
    assert_select "[data-segment-end='128.76']"
  end

  test "uses a preloaded interactive YouTube player" do
    get course_full_player_path(@course)

    assert_response :success
    assert_select "[data-controller~='main-video-player'][data-main-video-player-preload-player-value='true'][data-main-video-player-interactive-value='true']"
    assert_select "[data-main-video-player-target='player']"
    assert_select "[data-action*='main-video-player#togglePlayPause']", count: 0
    assert_select "[data-main-video-player-target='playButton']", count: 0
    assert_select "[data-main-video-player-target='progressBarContainer']", count: 0
    assert_select "a[aria-label='Back to course']"
  end

  test "loads the complete phrase graph only once" do
    2.times do |index|
      phrase = create_translated_phrase!(
        medium: @medium,
        l1: @english,
        l2: @english,
        text_l1: "Word #{index}",
        text_l2: "Word #{index}",
        timestamp: "00:0#{index}"
      )
      phrase.phrase_tokens.create!(
        l1_start_index: 0,
        l1_end_index: 0,
        start_timestamp: "00:0#{index}",
        end_timestamp: "00:0#{index}.50"
      )
    end

    queries = capture_selects { get course_full_player_path(@course) }

    assert_response :success
    phrase_queries = queries.grep(/FROM "phrases" WHERE "phrases"."medium_id"/)
    assert_equal 1, phrase_queries.size
    assert_no_match(/LIMIT 1/, phrase_queries.first)
    assert_equal 1, queries.grep(/FROM "lessons"/).size
  end

  private

  def capture_selects
    queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == "SCHEMA" || payload[:cached]

      queries << payload[:sql].squish if payload[:sql].to_s.lstrip.start_with?("SELECT")
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end
end
