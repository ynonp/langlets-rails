require "test_helper"

class ResyncTimestampsJobTest < ActiveJob::TestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    @english = languages(:english)
    @spanish = languages(:spanish)

    @medium = Medium.create!(
      url: "https://www.youtube.com/watch?v=test123",
      language: @english
    )

    @course = Course.create!(
      name: "Test Course",
      slug: "test-course-#{Time.zone.now.to_i}",
      main_media_url: "https://www.youtube.com/watch?v=test123",
      user: @user
    )

    @lesson = Lesson.create!(
      medium: @medium,
      slug: "test-lesson",
      course: @course,
      order: 0,
      name: "Test Lesson",
      user: @user
    )

    @activity = Activities::WatchVideoActivity.create!(
      lesson: @lesson,
      order: 1,
      user: @user
    )

    @phrase1 = create_translated_phrase!(
      medium: @medium,
      l1: @english,
      l2: @spanish,
      text_l1: "Hello",
      text_l2: "Hola",
      timestamp: "00:01:00"
    )

    @phrase2 = create_translated_phrase!(
      medium: @medium,
      l1: @english,
      l2: @spanish,
      text_l1: "World",
      text_l2: "Mundo",
      timestamp: "00:02:00"
    )

    @activity.phrases << @phrase1
    @activity.phrases << @phrase2
  end

  test "perform updates phrase timestamps from json_data" do
    json_data = [
      { "timestamp" => "00:01:30" },
      { "timestamp" => "00:02:30" }
    ]

    ResyncTimestampsJob.perform_now(@course.id, json_data)

    assert_equal "00:01:30", @phrase1.reload.timestamp
    assert_equal "00:02:30", @phrase2.reload.timestamp
  end

  test "perform calls sync_lesson_timestamps on course" do
    json_data = [
      { "timestamp" => "00:01:30" },
      { "timestamp" => "00:02:30" }
    ]

    ResyncTimestampsJob.perform_now(@course.id, json_data)

    # After perform, lesson timestamps should be synced
    @lesson.reload
    assert_equal "00:01:30", @lesson.start_timestamp
    expected_end = Phrase.to_string_timestamp(@phrase2.reload.timestamp_seconds + 5)
    assert_equal expected_end, @lesson.end_timestamp
  end

  test "verify_json_data! raises on phrase count mismatch" do
    json_data = [{ "timestamp" => "00:01:00" }] # only 1, but we have 2 phrases

    assert_raises(RuntimeError, /Phrase count mismatch/) do
      ResyncTimestampsJob.perform_now(@course.id, json_data)
    end
  end

  test "verify_json_data! raises on missing timestamp" do
    json_data = [
      { "timestamp" => "00:01:00" },
      { "timestamp" => nil }
    ]

    assert_raises(RuntimeError, /Missing timestamps at JSON indices: 1/) do
      ResyncTimestampsJob.perform_now(@course.id, json_data)
    end
  end

  test "verify_json_data! raises on blank timestamp" do
    json_data = [
      { "timestamp" => "00:01:00" },
      { "timestamp" => "" }
    ]

    assert_raises(RuntimeError, /Missing timestamps at JSON indices: 1/) do
      ResyncTimestampsJob.perform_now(@course.id, json_data)
    end
  end

  test "verify_json_data! reports all missing indices" do
    json_data = [
      { "timestamp" => nil },
      { "timestamp" => "" }
    ]

    assert_raises(RuntimeError, /Missing timestamps at JSON indices: 0, 1/) do
      ResyncTimestampsJob.perform_now(@course.id, json_data)
    end
  end
end
