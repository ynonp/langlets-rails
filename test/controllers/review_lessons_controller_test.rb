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
    lesson = pending_review

    get review_lessons_url(language_code: @english.iso_name)

    assert_response :success
    assert lesson.reload.review_started?
    assert_select ".activity-stepnav a[href='#{root_path}']", count: 1
    assert_select "[data-controller~='main-video-player'][data-action*='flashcard-activity:card-change->main-video-player#configureSegment']"
    assert_select "#main-player.hidden[data-main-video-player-target='playerContainer']"
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

  private

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
