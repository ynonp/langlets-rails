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
    assert_select "title", text: I18n.t("lessons.finish.page_title")
    assert_select "h1", text: I18n.t("lessons.finish.heading")
    assert_select "h2", text: I18n.t("lessons.finish.great_job")
    assert_select "p", text: I18n.t("lessons.finish.completed_message")
    assert_select "span", text: I18n.t("lessons.finish.xp_earned", count: @speech_activity.xp_value)
    assert_select "a", text: /Back to Course/, count: 0
    assert_select "a[href='#{course_path(@course.slug)}']", text: I18n.t("lessons.finish.continue"), count: 1
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
      assert_equal "underline decoration-emerald-500 decoration-[2.5px] underline-offset-4",
                   phrases_container.first["data-popover-translation-saved-token-classes-value"]
    end
  end

  test "flashcard shows the shared video player and configures its current phrase" do
    phrase = create_translated_phrase!(
      medium: @medium,
      l1: languages(:english),
      l2: languages(:english),
      text_l1: "Choose the missing word",
      text_l2: "Choose the missing word",
      timestamp: "00:04.00"
    )
    token = create_translated_token!(
      phrase:,
      translation: "missing",
      language: languages(:english),
      l1_start_index: 2,
      l1_end_index: 2,
      start_timestamp: "00:04.50",
      end_timestamp: "00:04.90"
    )
    activity = Activities::FlashcardActivity.create!(lesson: @lesson, order: 2, user: @user)
    activity.phrase_tokens << token

    get course_lesson_url(@course, @lesson, a: activity.order, lang: "en")

    assert_response :success
    assert_select "[data-controller~='main-video-player'][data-action*='flashcard-activity:card-change->main-video-player#configureSegment']"
    assert_select "#main-player:not(.hidden)"
    assert_select ".order-4[data-controller='flashcard-activity'][data-main-video-player-target~='videoSegment']" do |flashcard|
      assert_includes flashcard.first["data-action"], "video:play->main-video-player#seekToSegmentStartIfBefore"
      assert_select "[data-flashcard-activity-target='completion'].pt-4", count: 1
      assert_select "[data-flashcard-activity-target='completion'].my-auto", count: 0
    end
  end

  test "Hebrew lesson navigation and match activity use RTL progress and localized copy" do
    phrase = create_translated_phrase!(
      medium: @medium,
      l1: languages(:english),
      l2: languages(:hebrew),
      text_l1: "Choose the Hebrew meaning",
      text_l2: "בחרו במשמעות בעברית",
      timestamp: "00:04.00"
    )
    activity = Activities::MatchPhrasesActivity.create!(
      lesson: @lesson,
      order: 2,
      user: @user
    )
    activity.phrases << phrase
    host! "he.langlets.app"

    get course_lesson_path(@course, @lesson, a: activity.order)

    assert_response :success
    assert_select "html[lang='he'][dir='rtl']"
    assert_select "[data-progress-target='fill']" do |fills|
      assert_includes fills.first["class"], "start-0"
    end
    assert_select "[data-progress-target='dot']" do |dots|
      assert_includes dots.first["class"], "start-0"
      assert_nil dots.first["style"]
    end
    assert_select "[data-match-activity-target='progressText']",
                  text: "הקשיבו, ואז בחרו את המשמעות בעברית"
    assert_select "[data-match-activity-target='completionMessage'] a", text: "הבא"
  end

  test "Hebrew ordering activities and token chain localize their controls and counter" do
    phrase = create_translated_phrase!(
      medium: @medium,
      l1: languages(:english),
      l2: languages(:hebrew),
      text_l1: "Build sentence",
      text_l2: "בנו משפט",
      timestamp: "00:04.00"
    )
    token = create_translated_token!(
      phrase:,
      translation: "בנו",
      language: languages(:hebrew),
      l1_start_index: 0,
      l1_end_index: 4,
      index_type: :character_index
    )
    sort_activity = Activities::SortPhrasesActivity.create!(lesson: @lesson, order: 2, user: @user)
    word_order_activity = Activities::WordOrderActivity.create!(lesson: @lesson, order: 3, user: @user)
    tokens_chain_activity = Activities::TokensChainActivity.create!(lesson: @lesson, order: 4, user: @user)
    sort_activity.phrases << phrase
    word_order_activity.phrases << phrase
    tokens_chain_activity.phrase_tokens << token
    host! "he.langlets.app"

    get course_lesson_path(@course, @lesson, a: sort_activity.order)

    assert_response :success
    assert_select "#check-order", text: "בדיקת הסדר"
    assert_select "#result-message", text: "הסדר עדיין לא נכון. נסו להזיז שוב את השורות."

    get course_lesson_path(@course, @lesson, a: word_order_activity.order)

    assert_response :success
    assert_select "[data-word-order-activity-target='continueButton']", text: /בדיקה/

    get course_lesson_path(@course, @lesson, a: tokens_chain_activity.order)

    assert_response :success
    assert_select "[data-tokens-chain-activity-target='progressText']", text: "0 / 1 הותאמו"
  end

  test "native watch video renders saved vocabulary state" do
    phrase = create_translated_phrase!(
      medium: @medium,
      l1: languages(:english),
      l2: languages(:english),
      text_l1: "Saved word",
      text_l2: "Saved word",
      timestamp: "00:01.00"
    )
    token = create_translated_token!(
      phrase:,
      translation: "Saved",
      language: languages(:english),
      l1_start_index: 0,
      l1_end_index: 0
    )
    @user.phrase_token_users.create!(phrase_token: token, language: languages(:english))
    activity = Activities::WatchVideoActivity.create!(
      lesson: @lesson,
      order: 2,
      user: @user
    )
    activity.phrases << phrase

    get course_lesson_url(@course, @lesson, a: activity.order, lang: "en"),
        headers: { "User-Agent" => "LangletsNative", "Turbo-Frame" => "activity" }

    assert_response :success
    assert_includes response.headers["Cache-Control"], "max-age=600"
    assert_select "#phrases-container[data-controller='popover-translation']" do |container|
      assert_includes JSON.parse(container.first["data-popover-translation-saved-ids-value"]), token.id
      assert_equal token_translation_users_path,
                   container.first["data-popover-translation-saved-ids-url-value"]
      assert_equal "underline decoration-emerald-500 decoration-[2.5px] underline-offset-4",
                   container.first["data-popover-translation-saved-token-classes-value"]
      assert_select "[data-token-id='#{token.id}']"
      assert_select "[data-popover-translation-target='saveButton']"
    end
  end

  test "native read translated activity renders its text in the main scroll region" do
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
