# Starts an import and returns. It does not build the course.
#
# The AI work runs on the Deno pipeline server and reaches this app through
# PipelineCallbacksController; Imports::Finalizer — which every callback wakes
# up — is what publishes the course once the blob holds everything, and
# ImportRequestTimeoutJob is what ends the import if it never does. This job's
# whole responsibility is: claim the course, mark the requests importing, get
# the run started.
#
# It used to block on the run for as long as it took, which meant one worker
# thread per in-flight import and a timeout that only fired if the pipeline
# happened to hang in the read rather than anywhere else. Now several imports
# share a worker and the deadline is wall-clock, not connection-shaped.
class CreateCourseJob < ApplicationJob
  queue_as :default

  # No retry_on, deliberately. A failed Solid Queue execution stays failed, so
  # a raise here is final — which makes refunding in the rescue below correct
  # rather than a balance yo-yo. Adding retries naively would also be unsafe:
  # the rescue sets the course to `error`, and Course#process only claims a
  # `pending` course, so a second attempt would silently do nothing.
  def perform(create_song_progress_id, course_id)
    progress = CreateSongProgress.find(create_song_progress_id)
    course = Course.find(course_id)

    claimed = course.process do |claimed_course|
      Rails.logger.info "Starting CreateCourseJob #{create_song_progress_id} / #{course_id}"
      # Inside the claim: only the job that actually owns this course should move
      # its requests. If another job holds it, that one has already done this.
      start_imports!(claimed_course)
      trigger!(progress)
    end

    Rails.logger.info "Another job already processing or completed CreateSongProgress #{create_song_progress_id} / #{course_id}" unless claimed

    # A re-import of a record the pipeline already filled in has nothing to wait
    # for, so don't make it wait for a callback that will never come.
    Imports::Finalizer.call(progress) if claimed

  rescue => e
    # course is nil when the find itself failed; without the guard the
    # NoMethodError would mask the real error.
    course&.error!
    fail_imports!(course, e) if course

    Rails.logger.error "Course creation failed for course #{course_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # No mail from here: fail_imports! above went through Imports::Settlement,
    # which notifies every user who was waiting on this course.
    raise e
  end

  private

  # Fire-and-forget: the pipeline answers 202 and streams its results back to
  # PipelineCallbacksController. A raise here means the run never started at
  # all, which is the one failure this job is still on the hook for.
  def trigger!(progress)
    language = Language.find_by(english_name: progress.translation_language)
    return if progress.complete_for?(language)

    Rails.logger.info "CreateSongProgress #{progress.id}: triggering the pipeline at #{CreateSongPipelineHttp.base_url}"
    CreateSongPipelineHttp.new(progress: progress).call
  end

  # Requests waiting on this course. Usually one, but several users can ride on a
  # single import (see Imports::Create#join!).
  def imports_for(course)
    ImportRequest.where(course_id: course.id).where(status: [ :queued, :importing ])
  end

  def start_imports!(course)
    imports_for(course).update_all(status: ImportRequest.statuses[:importing], updated_at: Time.zone.now)
  end

  def fail_imports!(course, error)
    Imports::Settlement.fail_all!(imports_for(course).includes(:user), error.message)
  end
end
