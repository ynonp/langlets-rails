class AddCourseTranslationJob < ApplicationJob
  queue_as :default

  def perform(create_song_progress_id, course_id, language_id)
    progress = CreateSongProgress.find(create_song_progress_id)
    course = Course.find(course_id)
    language = Language.find(language_id)
    requests = ImportRequest.active.where(course: course, create_song_progress: progress, translation_language: language.english_name)

    requests.update_all(status: ImportRequest.statuses[:importing], updated_at: Time.zone.now)
    if progress.data.blank? || progress.data["phrases"].blank?
      if course.medium&.phrases&.exists?
        # The course already has content, so reconstruct the blob from it
        # instead of re-transcribing: a fresh transcription may segment
        # differently and misalign with the persisted tokens.
        CreateSongProgressRebuilder.new(course, progress: progress).call
      else
        progress.create_data
      end
    end
    progress.add_translation(language) unless progress.translation_complete?(language)
    CourseBuilder::BuildSong.new(progress, course).add_translation(language) unless course.translation_ready?(language)

    requests.find_each do |request|
      Enrollment.find_or_create_by!(user: request.user, course: course) { |row| row.source = :imported }
      request.update!(status: :ready, progress_percent: 100, failure_reason: nil)
      SendImportReadyPushJob.perform_later(request.id)
    end
  rescue => error
    course&.course_translations&.find_by(language_id: language_id)&.error!
    requests&.find_each do |request|
      if request.charged? && !request.refunded?
        Credits::Ledger.refund!(user: request.user, subject: request, idempotency_key: "refund:#{request.id}")
        request.refunded = true
      end
      request.update!(status: :failed, failure_reason: error.message.to_s.truncate(250))
    end
    raise
  end
end
