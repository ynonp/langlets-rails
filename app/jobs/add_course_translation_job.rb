# Starts a run for one extra language against a course that already exists, and
# returns. Like CreateCourseJob it no longer waits: Imports::Finalizer attaches
# the translation and marks the requests ready once the language's payload is
# finalized, and ImportRequestTimeoutJob ends the import if it never is.
class AddCourseTranslationJob < ApplicationJob
  queue_as :default

  def perform(create_song_progress_id, course_id, language_id)
    progress = CreateSongProgress.find(create_song_progress_id)
    course = Course.find(course_id)
    language = Language.find(language_id)
    requests = ImportRequest.active.where(course: course, create_song_progress: progress, translation_language: language.english_name)

    requests.update_all(status: ImportRequest.statuses[:importing], updated_at: Time.zone.now)

    if (progress.data.blank? || progress.data["phrases"].blank?) && course.medium&.phrases&.exists?
      # The course already has content, so reconstruct the blob from it instead
      # of re-transcribing: a fresh transcription may segment differently and
      # misalign with the persisted tokens.
      CreateSongProgressRebuilder.new(course, progress: progress).call
      progress.reload
    end

    # One run covers whatever is still missing: the pipeline transcribes only
    # when there are no phrases yet, and guards every other branch on the same
    # data keys, so a record that just needs the new language only gets that.
    CreateSongPipelineHttp.new(progress: progress, language: language).call unless progress.complete_for?(language)

    # A no-op unless the record already holds this language — the usual case is
    # a callback getting here first.
    Imports::Finalizer.call(progress)
  rescue => error
    course&.course_translations&.find_by(language_id: language_id)&.error!
    Imports::Settlement.fail_all!(requests.to_a, error.message) if requests
    raise
  end
end
