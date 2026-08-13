class CleanupExpiredReviewLessonsJob < ApplicationJob
  queue_as :default

  def perform
    expired = Lesson.review_lessons.review_expired
    count = expired.destroy_all.size
    Rails.logger.info("CleanupExpiredReviewLessonsJob removed #{count} expired review lessons")
  end
end
