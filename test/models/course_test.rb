require "test_helper"

class CourseTest < ActiveJob::TestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
  end

  test "show_full_course_player defaults to true for new courses" do
    course = Course.new(
      name: "Test Course",
      slug: "test-course-#{Time.zone.now.to_i}",
      main_media_url: "https://www.youtube.com/watch?v=test123",
      user: @user
    )
    
    assert course.show_full_course_player, "show_full_course_player should default to true"
  end

  test "show_full_course_player can be set to false" do
    course = Course.create!(
      name: "Test Course No Player",
      slug: "test-course-no-player-#{Time.zone.now.to_i}",
      main_media_url: "https://www.youtube.com/watch?v=test456",
      user: @user,
      show_full_course_player: false
    )
    
    assert_not course.show_full_course_player, "show_full_course_player should be false when explicitly set"
  end

  test "with_full_player scope returns only courses with full player enabled" do
    # Create courses with different show_full_course_player values
    course_with_player = Course.create!(
      name: "Course With Player",
      slug: "course-with-player-#{Time.zone.now.to_i}",
      main_media_url: "https://www.youtube.com/watch?v=test789",
      user: @user,
      show_full_course_player: true
    )
    
    course_without_player = Course.create!(
      name: "Course Without Player",
      slug: "course-without-player-#{Time.zone.now.to_i}",
      main_media_url: "https://www.youtube.com/watch?v=test101",
      user: @user,
      show_full_course_player: false
    )
    
    courses_with_player = Course.with_full_player
    
    assert_includes courses_with_player, course_with_player
    assert_not_includes courses_with_player, course_without_player
  end

  test "show_full_course_player cannot be nil" do
    course = Course.new(
      name: "Test Course Nil",
      slug: "test-course-nil-#{Time.zone.now.to_i}",
      main_media_url: "https://www.youtube.com/watch?v=test202",
      user: @user
    )
    
    # Try to set to nil - should raise a database constraint error
    course.show_full_course_player = nil
    
    assert_raises(ActiveRecord::NotNullViolation) do
      course.save!
    end
  end

  # --- sync_lesson_timestamps tests ---

  def setup_sync_test
    @english = languages(:english)
    @spanish = languages(:spanish)

    @medium = Medium.create!(
      url: "https://www.youtube.com/watch?v=sync-test",
      language: @english
    )

    @course = Course.create!(
      name: "Sync Test Course",
      slug: "sync-test-course-#{Time.zone.now.to_i}",
      main_media_url: "https://www.youtube.com/watch?v=sync-test",
      user: @user
    )

    @lesson1 = Lesson.create!(
      medium: @medium,
      slug: "lesson-1",
      course: @course,
      order: 0,
      name: "Lesson 1",
      user: @user
    )

    @lesson2 = Lesson.create!(
      medium: @medium,
      slug: "lesson-2",
      course: @course,
      order: 1,
      name: "Lesson 2",
      user: @user
    )

    @activity1 = Activities::WatchVideoActivity.create!(lesson: @lesson1, order: 1, user: @user)
    @activity2 = Activities::WatchVideoActivity.create!(lesson: @lesson2, order: 1, user: @user)

    @phrase1 = create_translated_phrase!(medium: @medium, l1: @english, l2: @spanish, text_l1: "A", text_l2: "A", timestamp: "00:01:00")
    @phrase2 = create_translated_phrase!(medium: @medium, l1: @english, l2: @spanish, text_l1: "B", text_l2: "B", timestamp: "00:02:00")
    @phrase3 = create_translated_phrase!(medium: @medium, l1: @english, l2: @spanish, text_l1: "C", text_l2: "C", timestamp: "00:03:00")
    @phrase4 = create_translated_phrase!(medium: @medium, l1: @english, l2: @spanish, text_l1: "D", text_l2: "D", timestamp: "00:04:00")

    @activity1.phrases << @phrase1
    @activity1.phrases << @phrase2
    @activity2.phrases << @phrase3
    @activity2.phrases << @phrase4
  end

  test "sync_lesson_timestamps sets start_timestamp to first phrase" do
    setup_sync_test

    @course.sync_lesson_timestamps

    assert_equal "00:01:00", @lesson1.reload.start_timestamp
    assert_equal "00:03:00", @lesson2.reload.start_timestamp
  end

  test "sync_lesson_timestamps sets end_timestamp to first phrase of next lesson" do
    setup_sync_test

    @course.sync_lesson_timestamps

    # Lesson 1 ends when Lesson 2 starts (first phrase of lesson 2)
    assert_equal "00:03:00", @lesson1.reload.end_timestamp
  end

  test "sync_lesson_timestamps sets end_timestamp of last lesson to last phrase + 5 seconds" do
    setup_sync_test

    @course.sync_lesson_timestamps

    # Last lesson: end = last phrase timestamp + 5 seconds
    expected_end = Phrase.to_string_timestamp(@phrase4.timestamp_seconds + 5)
    assert_equal expected_end, @lesson2.reload.end_timestamp
  end

  test "sync_lesson_timestamps skips lessons with no phrases" do
    setup_sync_test

    empty_lesson = Lesson.create!(
      medium: @medium,
      slug: "empty-lesson",
      course: @course,
      order: 2,
      name: "Empty",
      user: @user
    )

    # Should not raise
    @course.sync_lesson_timestamps

    # Empty lesson should remain unchanged
    assert_nil empty_lesson.reload.start_timestamp
    assert_nil empty_lesson.reload.end_timestamp
  end

  test "sync_lesson_timestamps handles single lesson" do
    setup_sync_test
    @lesson2.destroy!

    @course.sync_lesson_timestamps

    assert_equal "00:01:00", @lesson1.reload.start_timestamp
    expected_end = Phrase.to_string_timestamp(@phrase2.timestamp_seconds + 5)
    assert_equal expected_end, @lesson1.reload.end_timestamp
  end

  # The reason the column is nullable and was never backfilled: YouTube covers
  # derive from main_media_url, so every pre-existing row keeps working.
  test "a YouTube cover is derived when the column is empty" do
    course = build_course("https://www.youtube.com/watch?v=dQw4w9WgXcQ")

    assert_nil course[:thumbnail_url]
    assert_equal "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg", course.thumbnail_url
    assert_equal :youtube, course.provider
    assert_equal "dQw4w9WgXcQ", course.video_id
  end

  # TikTok covers are signed CDN URLs that cannot be derived, so the stored
  # value captured from oEmbed at import time is the only source.
  test "a TikTok cover comes from the stored column" do
    stored = "https://p16-sign-va.tiktokcdn.com/obj/abc?x-expires=1"
    course = build_course(
      "https://www.tiktok.com/@scout2015/video/6718335390845095173",
      thumbnail_url: stored
    )

    assert_equal stored, course.thumbnail_url
    assert course.tiktok?
    assert_equal "6718335390845095173", course.video_id
  end

  test "a TikTok course with no stored cover has none to render" do
    course = build_course("https://www.tiktok.com/@scout2015/video/6718335390845095173")

    assert_nil course.thumbnail_url
  end

  test "a stored cover wins over derivation" do
    course = build_course(
      "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      thumbnail_url: "https://example.com/custom.jpg"
    )

    assert_equal "https://example.com/custom.jpg", course.thumbnail_url
  end

  test "regenerate deletes the old graph and retries its import with an empty pipeline cache" do
    english = languages(:english)
    spanish = languages(:spanish)
    url = "https://www.youtube.com/watch?v=regenerate1"
    progress = CreateSongProgress.create!(
      youtubeurl: url,
      clip_language: "Spanish",
      translation_language: "English",
      data: { "phrases" => [ { "text_l1" => "old" } ] }
    )
    course = Course.create!(
      name: "Old Course",
      slug: "old-course-regenerate1",
      main_media_url: url,
      youtube_video_id: "regenerate1",
      language: spanish,
      user: @user,
      status: :published,
      create_song_progress: progress
    )
    medium = Medium.create!(url: url, language: spanish)
    Lesson.create!(course: course, medium: medium, user: @user, name: "Old Lesson", slug: "old-lesson")
    request = @user.import_requests.create!(
      youtube_url: url,
      youtube_video_id: "regenerate1",
      clip_language: "Spanish",
      translation_language: "English",
      course: course,
      create_song_progress: progress,
      status: :ready
    )

    assert_enqueued_with(job: CreateCourseJob) do
      assert_equal request, course.regenerate!
    end

    replacement = request.reload.course
    refute Course.exists?(course.id)
    refute Medium.exists?(medium.id)
    assert_equal({}, progress.reload.data)
    assert request.queued?
    assert replacement.pending?
    assert_equal course.slug, replacement.slug
    assert_equal progress, replacement.create_song_progress
    assert_equal english.english_name, request.translation_language
  end

  test "regenerate creates a failed import request for the course owner before retrying" do
    spanish = languages(:spanish)
    url = "https://www.youtube.com/watch?v=regenerate2"
    progress = CreateSongProgress.create!(
      youtubeurl: url,
      clip_language: "Spanish",
      translation_language: "English",
      data: { "format_version" => 2 }
    )
    course = Course.create!(
      name: "Legacy Course",
      slug: "legacy-course-regenerate2",
      main_media_url: url,
      youtube_video_id: "regenerate2",
      language: spanish,
      user: @user,
      status: :published,
      create_song_progress: progress
    )

    assert_difference -> { ImportRequest.count }, 1 do
      course.regenerate!
    end

    request = ImportRequest.find_by!(user: @user, youtube_video_id: "regenerate2")
    assert request.queued?
    assert_equal @user, request.user
    assert_equal progress, request.create_song_progress
    assert request.course.pending?
    refute_equal course.id, request.course_id
  end

  private

  def build_course(url, **attributes)
    Course.create!(
      name: "Provider Course",
      slug: "provider-course-#{SecureRandom.hex(4)}",
      main_media_url: url,
      user: @user,
      **attributes
    )
  end
end
