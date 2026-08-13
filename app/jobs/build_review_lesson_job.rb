class BuildReviewLessonJob < ApplicationJob
  queue_as :default

  def perform(user_id, language_id)
    user = User.find(user_id)
    language = Language.find(language_id)

    user.with_lock do
      return if user.lessons.pending_review_lessons.where(review_language: language).exists?

      ReviewLessonBuilder.new(user, language_code: language.iso_name).build!
    end
  end
end
