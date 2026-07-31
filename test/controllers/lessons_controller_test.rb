require "test_helper"

class LessonsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "lesson-finish@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @medium = Medium.create!(
      url: "https://www.youtube.com/watch?v=lessonfinish",
      language: languages(:english)
    )
    @course = Course.create!(
      name: "Lesson finish course",
      slug: "lesson-finish-course",
      main_media_url: @medium.url,
      language: languages(:english),
      user: @user
    )
    publish_publicly(@course)
    @lesson = Lesson.create!(
      course: @course,
      medium: @medium,
      user: @user,
      slug: "speech-lesson",
      name: "Speech lesson",
      order: 1
    )
    @speech_activity = Activities::SpeakActivity.create!(
      lesson: @lesson,
      order: 1,
      user: @user
    )

    post user_session_url, params: {
      user: { email: @user.email, password: "password123" }
    }
  end

  test "finish marks lesson complete when an activity was skipped" do
    assert_not ActivityUser.exists?(activity: @speech_activity, user: @user)

    assert_difference -> { LessonUser.where(lesson: @lesson, user: @user).count }, 1 do
      get finish_course_lesson_url(@course, @lesson)
    end

    assert_response :success
    assert @lesson.completed_by?(@user)
    assert_not ActivityUser.exists?(activity: @speech_activity, user: @user)
  end

  test "finish is idempotent for an already completed lesson" do
    LessonUser.create!(lesson: @lesson, user: @user)

    assert_no_difference -> { LessonUser.where(lesson: @lesson, user: @user).count } do
      get finish_course_lesson_url(@course, @lesson)
    end

    assert_response :success
  end

  test "watch video uses a deterministic media height" do
    phrase = Phrase.create!(
      medium: @medium,
      l1: languages(:english),
      text_l1: "A test phrase",
      timestamp: "00:01.00"
    )
    activity = Activities::WatchVideoActivity.create!(
      lesson: @lesson,
      order: 2,
      user: @user
    )
    activity.phrases << phrase

    get course_lesson_url(@course, @lesson, a: activity.order)

    assert_response :success
    assert_select "#main-player" do |players|
      assert_includes players.first["class"], "h-[clamp(160px,30vh,280px)]"
      assert_includes players.first["data-action"], "loadedmetadata->main-video-player#setMediaRatio:capture"
    end
    assert_select "[data-main-video-player-target~='media']" do |media|
      assert_includes media.first["class"], "data-[ratio=landscape]:[&_video]:object-contain"
    end

    assert_select "[data-controller='watch-video-activity']" do |watch_activity|
      actions = watch_activity.first["data-action"]
      assert_includes actions, "watch-video-activity:pause->main-video-player#stopPlayback"
      assert_includes actions, "watch-video-activity:resume->main-video-player#resume"
    end

    assert_select "#phrases-container" do |phrases_container|
      actions = phrases_container.first["data-action"]
      assert_includes actions, "click->watch-video-activity#handleTranslationClick"
      assert_includes actions, "click@document->watch-video-activity#resumeAfterTranslation"
    end
  end

  test "native read translated activity renders its text in the main scroll region" do
    @user.update!(ios_lang: "en")
    phrase = Phrase.create!(
      medium: @medium,
      l1: languages(:english),
      text_l1: "Une phrase de test",
      timestamp: "00:01.00"
    )
    PhraseTranslation.create!(
      phrase:,
      language: languages(:english),
      text: "A visible translated phrase"
    )
    activity = Activities::ReadTranslatedActivity.create!(
      lesson: @lesson,
      order: 2,
      user: @user
    )
    activity.phrases << phrase

    get course_lesson_url(@course, @lesson, a: activity.order, lang: "en"),
        headers: { "User-Agent" => "LangletsNative" }

    assert_response :success
    assert_select "[data-testid='read-translated-scroll']" do
      assert_select "p", text: "A visible translated phrase"
    end
  end
end
