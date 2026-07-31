class BuildReviewLessonJob < ApplicationJob
  queue_as :default

  def perform(lesson_id)
    lesson = Lesson.review_build_pending.find(lesson_id)
    ReviewLessonBuilder.new(
      lesson.user,
      language_code: lesson.review_language&.iso_name
    ).build!(lesson: lesson)
  rescue StandardError => error
    Lesson.where(id: lesson_id).update_all(
      review_build_status: Lesson.review_build_statuses[:failed],
      review_build_error: error.message.truncate(250),
      updated_at: Time.zone.now
    )
    raise
  end
end
