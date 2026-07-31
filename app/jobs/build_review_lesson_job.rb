class BuildReviewLessonJob < ApplicationJob
  queue_as :default

  def perform(build_id)
    build = nil
    ReviewLessonBuild.transaction do
      build = ReviewLessonBuild.lock.find(build_id)
      return unless build.pending?

      lesson = ReviewLessonBuilder.new(
        build.user,
        language_code: build.language&.iso_name
      ).build!
      build.update!(lesson: lesson, status: :ready, error: nil)
    end

    broadcast_visit(build, routes.review_lesson_path(build.lesson))
  rescue StandardError => error
    ReviewLessonBuild.where(id: build_id).update_all(
      status: ReviewLessonBuild.statuses[:failed],
      error: error.message.truncate(250),
      updated_at: Time.zone.now
    )
    failed_build = ReviewLessonBuild.find_by(id: build_id)
    if failed_build
      broadcast_visit(
        failed_build,
        routes.review_lesson_build_path(failed_build.request_id)
      )
    end
    raise
  end

  private

  def broadcast_visit(build, url)
    Turbo::StreamsChannel.broadcast_action_to(
      build,
      action: :visit,
      attributes: { url: url }
    )
  rescue StandardError => error
    Rails.logger.warn(
      "Review lesson build #{build.id} could not broadcast its redirect: #{error.message}"
    )
  end

  def routes
    Rails.application.routes.url_helpers
  end
end
