require "test_helper"

class ReviewLessonsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "review@example.com", password: "password123", confirmed_at: Time.zone.now)
    @other_user = User.create!(email: "other-review@example.com", password: "password123", confirmed_at: Time.zone.now)
    @english = languages(:english)
    post user_session_url, params: {
      user: { email: @user.email, password: "password123" }
    }
  end

  test "show starts the current pending review without a lesson id" do
    PhraseTokenUser.create_custom!(user: @user, sentence: "hello world", language: @english,
      token_range: 1..1, translation: "mundo", translation_language: languages(:spanish))
    lesson = @user.current_review_lesson(@english.iso_name)

    get review_lessons_url(language_code: @english.iso_name)

    assert_response :success
    assert lesson.reload.review_started?
    assert_not_nil lesson.review_started_at
    assert_select ".activity-stepnav a[href='#{root_path}']", count: 1
    assert_select "[data-controller~='main-video-player'][data-action*='flashcard-activity:card-change->main-video-player#configureSegment']"
    assert_select "[data-controller~='main-video-player'][data-action*='write-missing-word-activity:card-change->main-video-player#configureSegment']"
    assert_select "#main-player.hidden[data-main-video-player-target='playerContainer']"
    assert_select "[data-controller='write-missing-word-activity'][data-main-video-player-target='videoListener videoSegment'][data-show-player='true']"
    assert_select "[data-write-missing-word-activity-target='completionTranslation']"
    assert_select "[data-action='click->write-missing-word-activity#continue']"
  end

  test "an empty review remains navigable" do
    pending_review

    get review_lessons_url(language_code: @english.iso_name)

    assert_response :success
    assert_select '[data-testid="no-translation-questions"] a[href]', count: 1
  end

  test "show builds and starts a review when an existing user has none ready" do
    assert_difference("Lesson.count", 1) do
      get review_lessons_url(language_code: @english.iso_name)
    end

    assert_response :success
    assert @user.lessons.review_lessons.last.review_started?
  end

  test "show resumes a started review" do
    lesson = pending_review
    lesson.update!(review_build_status: :started)

    get review_lessons_url(language_code: @english.iso_name)

    assert_response :success
  end

  test "show only uses the requested language's current review" do
    arabic = languages(:arabic)
    pending_review(language: arabic)
    english_lesson = pending_review

    get review_lessons_url(language_code: @english.iso_name)

    assert_response :success
    assert english_lesson.reload.review_started?
  end

  test "show requires authentication" do
    delete destroy_user_session_url

    get review_lessons_url(language_code: @english.iso_name)

    assert_response :redirect
    assert_match new_user_session_path, response.location
  end

  test "finish marks the started review finished and queues a replacement" do
    lesson = pending_review
    lesson.update!(review_build_status: :started)

    assert_enqueued_with(job: BuildReviewLessonJob, args: [ @user.id, @english.id ]) do
      get finish_review_lessons_url(language_code: @english.iso_name)
    end

    assert_response :success
    assert lesson.reload.review_finished?
  end

  test "recall saves first-try success once and a failed recall resets the word" do
    entry, activity = recall_entry
    post recall_review_lessons_url, params: { activity_id: activity.id, phrase_token_id: entry.phrase_token_id, remembered: true }, as: :json
    assert_response :no_content
    assert entry.reload.familiarity_learning?
    due_at = entry.next_review_at
    post recall_review_lessons_url, params: { activity_id: activity.id, phrase_token_id: entry.phrase_token_id, remembered: false }, as: :json
    assert_response :no_content
    assert_equal due_at, entry.reload.next_review_at

    travel_to(due_at + 1.second) do
      # Finish the previous session before taking the next one.
      activity.lesson.update!(review_build_status: :finished)
      next_lesson = @user.current_review_lesson("en")
      next_lesson.update!(review_build_status: :started)
      next_activity = next_lesson.activities.find_by!(type: "Activities::WriteMissingWordActivity")
      post recall_review_lessons_url, params: { activity_id: next_activity.id, phrase_token_id: entry.phrase_token_id, remembered: false }, as: :json
      assert_response :no_content
      assert entry.reload.familiarity_new_word?
      assert_equal 10.minutes.from_now, entry.next_review_at
    end
  end

  test "recall rejects another user's activity and tokens outside the activity" do
    entry, activity = recall_entry
    other_activity = Activities::WriteMissingWordActivity.create!(user: @other_user, lesson: pending_review, order: 2)
    post recall_review_lessons_url, params: { activity_id: other_activity.id, phrase_token_id: entry.phrase_token_id, remembered: true }, as: :json
    assert_response :not_found
    other = PhraseTokenUser.create_custom!(user: @user, sentence: "another word", language: @english,
      token_range: 1..1, translation: "meaning", translation_language: languages(:spanish))
    post recall_review_lessons_url, params: { activity_id: activity.id, phrase_token_id: other.phrase_token_id, remembered: true }, as: :json
    assert_response :not_found
    assert entry.reload.familiarity_new_word?
  end

  test "recall requires a started review, a typing exercise and a boolean outcome" do
    entry, activity = recall_entry
    post recall_review_lessons_url, params: { activity_id: activity.id, phrase_token_id: entry.phrase_token_id, remembered: "false" }, as: :json
    assert_response :unprocessable_entity
    activity.lesson.update!(review_build_status: :finished)
    post recall_review_lessons_url, params: { activity_id: activity.id, phrase_token_id: entry.phrase_token_id, remembered: true }, as: :json
    assert_response :unprocessable_entity
    activity.lesson.update!(review_build_status: :started)
    flashcard = Activities::FlashcardActivity.create!(user: @user, lesson: activity.lesson, order: 2)
    flashcard.phrase_tokens << entry.phrase_token
    post recall_review_lessons_url, params: { activity_id: flashcard.id, phrase_token_id: entry.phrase_token_id, remembered: true }, as: :json
    assert_response :unprocessable_entity
    assert entry.reload.familiarity_new_word?
  end

  test "recall requires authentication" do
    entry, activity = recall_entry
    delete destroy_user_session_url
    post recall_review_lessons_url, params: { activity_id: activity.id, phrase_token_id: entry.phrase_token_id, remembered: true }, as: :json
    assert_response :unauthorized
    assert entry.reload.familiarity_new_word?
  end

  private

  def recall_entry
    entry = PhraseTokenUser.create_custom!(user: @user, sentence: "hello world", language: @english,
      token_range: 1..1, translation: "mundo", translation_language: languages(:spanish))
    lesson = @user.current_review_lesson("en")
    lesson.update!(review_build_status: :started)
    [ entry, lesson.activities.find_by!(type: "Activities::WriteMissingWordActivity") ]
  end

  def pending_review(language: @english)
    Lesson.create!(
      user: @user,
      name: "Review Words (#{language.iso_name})",
      review_language: language,
      review_build_status: :pending
    ).tap do |lesson|
      Activities::WriteMissingWordActivity.create!(lesson: lesson, user: @user, order: 1)
    end
  end
end
