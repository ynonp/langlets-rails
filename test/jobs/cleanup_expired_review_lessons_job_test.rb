require "test_helper"

class CleanupExpiredReviewLessonsJobTest < ActiveJob::TestCase
  test "deletes expired reviews but keeps started and finished reviews" do
    user = User.create!(email: "review-cleanup@example.com", password: "password123", confirmed_at: Time.zone.now)
    language = languages(:english)
    expired = create_review(user, language, :expired)
    started = create_review(user, language, :started)
    finished = create_review(user, language, :finished)

    CleanupExpiredReviewLessonsJob.perform_now

    assert_not Lesson.exists?(expired.id)
    assert Lesson.exists?(started.id)
    assert Lesson.exists?(finished.id)
  end

  private

  def create_review(user, language, status)
    Lesson.create!(user:, review_language: language, review_build_status: status, name: "Review")
  end
end
