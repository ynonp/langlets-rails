require "test_helper"

class BuildReviewLessonJobTest < ActiveJob::TestCase
  setup do
    @user = User.create!(email: "review-job@example.com", password: "password123", confirmed_at: Time.zone.now)
    @english = languages(:english)
  end

  test "creates a pending review lesson" do
    assert_difference("Lesson.count", 1) do
      BuildReviewLessonJob.perform_now(@user.id, @english.id)
    end

    lesson = @user.lessons.review_lessons.last
    assert lesson.review_pending?
    assert_equal @english, lesson.review_language
  end

  test "does not create a duplicate pending review" do
    BuildReviewLessonJob.perform_now(@user.id, @english.id)

    assert_no_difference("Lesson.count") do
      BuildReviewLessonJob.perform_now(@user.id, @english.id)
    end
  end
end
