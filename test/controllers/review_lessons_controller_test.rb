require "test_helper"

class ReviewLessonsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    @english = languages(:english)
    @spanish = languages(:spanish)
    @hebrew = languages(:hebrew)
    @arabic = languages(:arabic)

    @medium = Medium.create!(
      url: "https://www.youtube.com/watch?v=test123",
      language: @english
    )

    @phrase_en = create_translated_phrase!(
      medium: @medium,
      l1: @english,
      l2: @spanish,
      text_l1: "Hello world",
      text_l2: "Hola mundo",
      timestamp: "00:01:30"
    )

    @phrase_ar = create_translated_phrase!(
      medium: @medium,
      l1: @arabic,
      l2: @english,
      text_l1: "مرحبا بالعالم",
      text_l2: "Hello world",
      timestamp: "00:02:00"
    )

    @phrase_he = create_translated_phrase!(
      medium: @medium,
      l1: @hebrew,
      l2: @english,
      text_l1: "שלום עולם",
      text_l2: "Hello world",
      timestamp: "00:03:00"
    )

    @token_en1 = create_translated_token!(
      phrase: @phrase_en,
      l1_start_index: 0,
      l1_end_index: 4,
      index_type: :character_index,
      translation: "Hola"
    )

    @token_en2 = create_translated_token!(
      phrase: @phrase_en,
      l1_start_index: 6,
      l1_end_index: 10,
      index_type: :character_index,
      translation: "Mundo"
    )

    @token_ar1 = create_translated_token!(
      phrase: @phrase_ar,
      l1_start_index: 0,
      l1_end_index: 4,
      index_type: :character_index,
      translation: "Hi"
    )

    @token_he = create_translated_token!(
      phrase: @phrase_he,
      l1_start_index: 0,
      l1_end_index: 4,
      index_type: :character_index,
      translation: "Hi"
    )

    post user_session_url, params: {
      user: {
        email: @user.email,
        password: "password123"
      }
    }
  end

  test "create builds review lesson for specific language" do
    @user.saved_phrase_tokens << @token_en1
    @user.saved_phrase_tokens << @token_ar1
    @user.saved_phrase_tokens << @token_he

    perform_enqueued_jobs do
      post review_lessons_url(language_code: @arabic.iso_name)
    end

    assert_response :redirect
    build = ReviewLessonBuild.last
    assert_match review_lesson_build_path(build.request_id), response.location
    assert build.ready?

    lesson = build.lesson
    assert_equal "Review Words (#{@arabic.iso_name})", lesson.name

    lesson_tokens = lesson.activities.flat_map(&:phrase_tokens)
    assert_includes lesson_tokens, @token_ar1
    assert_not_includes lesson_tokens, @token_en1
    assert_not_includes lesson_tokens, @token_he
  end

  test "create builds review lesson without language parameter" do
    @user.saved_phrase_tokens << @token_en1
    @user.saved_phrase_tokens << @token_ar1

    perform_enqueued_jobs { post review_lessons_url }

    assert_response :redirect

    build = ReviewLessonBuild.last
    assert_match review_lesson_build_path(build.request_id), response.location
    lesson = build.lesson
    assert_equal "Review Words", lesson.name

    lesson_tokens = lesson.activities.flat_map(&:phrase_tokens)
    assert_includes lesson_tokens, @token_en1
    assert_includes lesson_tokens, @token_ar1
  end

  test "create requires authentication" do
    delete destroy_user_session_url

    @user.saved_phrase_tokens << @token_en1

    post review_lessons_url(language_code: @english.iso_name)

    assert_response :redirect
    assert_match new_user_session_path, response.location
  end

  test "create redirects immediately to an animated waiting page" do
    @user.saved_phrase_tokens << @token_en1

    assert_no_difference("Lesson.count") do
      assert_enqueued_with(job: BuildReviewLessonJob) do
        post review_lessons_url(language_code: @english.iso_name)
      end
    end

    build = ReviewLessonBuild.last
    assert build.pending?
    assert_equal @english, build.language
    assert_match review_lesson_build_path(build.request_id), response.location

    get review_lesson_build_url(build.request_id)

    assert_response :success
    assert_select "turbo-cable-stream-source", count: 1
    assert_select "meta[http-equiv='refresh'][content='10']"
    assert_select "h1", text: "Your vocabulary review is being created"
  end

  test "build page redirects when the job finished before cable connected" do
    @user.saved_phrase_tokens << @token_en1
    lesson = ReviewLessonBuilder.new(@user, language_code: @english.iso_name).build!
    build = @user.review_lesson_builds.create!(
      language: @english,
      lesson: lesson,
      status: :ready
    )

    get review_lesson_build_url(build.request_id)

    assert_redirected_to review_lesson_path(lesson)
  end

  test "build page renders a retry after failure" do
    build = @user.review_lesson_builds.create!(
      language: @english,
      status: :failed,
      error: "Something broke"
    )

    get review_lesson_build_url(build.request_id)

    assert_response :success
    assert_select "h1", text: "That review needs another try"
    assert_select "form[action='#{review_lessons_path(language_code: @english.iso_name)}']"
  end

  test "build page only allows access to the owning user" do
    build = @user.review_lesson_builds.create!(language: @english)
    other_user = User.create!(
      email: "review-build-owner@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    delete destroy_user_session_url
    post user_session_url, params: {
      user: {
        email: other_user.email,
        password: "password123"
      }
    }

    get review_lesson_build_url(build.request_id)

    assert_response :not_found
  end

  test "show displays review lesson with only language-specific tokens" do
    @user.saved_phrase_tokens << @token_en1
    @user.saved_phrase_tokens << @token_en2
    @user.saved_phrase_tokens << @token_ar1

    lesson = ReviewLessonBuilder.new(@user, language_code: @english.iso_name).build!

    get review_lesson_url(lesson)

    assert_response :success
  end

  test "show requires authentication" do
    delete destroy_user_session_url

    @user.saved_phrase_tokens << @token_en1
    lesson = ReviewLessonBuilder.new(@user).build!

    get review_lesson_url(lesson)

    assert_response :redirect
    assert_match new_user_session_path, response.location
  end

  test "show only allows access to user's own lessons" do
    other_user = User.create!(
      email: "other@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    @user.saved_phrase_tokens << @token_en1
    lesson = ReviewLessonBuilder.new(@user).build!

    delete destroy_user_session_url
    post user_session_url, params: {
      user: {
        email: other_user.email,
        password: "password123"
      }
    }

    get review_lesson_url(lesson)

    assert_response :not_found
  end

  test "finish adds xp and redirects" do
    @user.saved_phrase_tokens << @token_en1
    lesson = ReviewLessonBuilder.new(@user).build!

    get finish_review_lesson_url(lesson)

    assert_response :success
  end

  test "language separated lessons work independently" do
    @user.saved_phrase_tokens << @token_en1
    @user.saved_phrase_tokens << @token_en2
    @user.saved_phrase_tokens << @token_ar1
    @user.saved_phrase_tokens << @token_he

    perform_enqueued_jobs { post review_lessons_url(language_code: @english.iso_name) }
    assert_response :redirect
    lesson_en = Lesson.find_by(name: "Review Words (#{@english.iso_name})")

    perform_enqueued_jobs { post review_lessons_url(language_code: @arabic.iso_name) }
    assert_response :redirect
    lesson_ar = Lesson.find_by(name: "Review Words (#{@arabic.iso_name})")

    perform_enqueued_jobs { post review_lessons_url(language_code: @hebrew.iso_name) }
    assert_response :redirect
    lesson_he = Lesson.find_by(name: "Review Words (#{@hebrew.iso_name})")

    tokens_en = lesson_en.activities.flat_map(&:phrase_tokens)
    tokens_ar = lesson_ar.activities.flat_map(&:phrase_tokens)
    tokens_he = lesson_he.activities.flat_map(&:phrase_tokens)

    assert_includes tokens_en, @token_en1
    assert_includes tokens_en, @token_en2
    assert_not_includes tokens_en, @token_ar1
    assert_not_includes tokens_en, @token_he

    assert_includes tokens_ar, @token_ar1
    assert_not_includes tokens_ar, @token_en1
    assert_not_includes tokens_ar, @token_he

    assert_includes tokens_he, @token_he
    assert_not_includes tokens_he, @token_en1
    assert_not_includes tokens_he, @token_ar1
  end
end
