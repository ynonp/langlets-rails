# The backstop that makes "stuck forever" impossible.
#
# Every ImportRequest schedules one of these for ImportRequest::TIMEOUT after it
# is created (ImportRequest#schedule_timeout), so the deadline is wall-clock time
# from the moment the user asked — not from a worker picking the job up, and not
# dependent on the pipeline reporting anything at all. A run that dies silently,
# a pipeline host that never comes back, a callback that never arrives: all of
# them end here rather than leaving a card spinning on the Queue screen.
#
# It is deliberately the *only* deadline in the system. The trigger no longer
# blocks, so there is no HTTP read timeout to tune and no worker to pin.
class ImportRequestTimeoutJob < ApplicationJob
  queue_as :default

  def perform(import_request_id)
    import_request = ImportRequest.find_by(id: import_request_id)
    return if import_request.nil? || !import_request.active?

    # The last patch and the finalizer that acts on it are not atomic, so ask
    # once more before giving up: an import whose data is sitting right there
    # must not be failed on a technicality.
    Imports::Finalizer.call(import_request.create_song_progress) if import_request.create_song_progress
    return unless import_request.reload.active?

    Rails.logger.warn "ImportRequest #{import_request.id} timed out after #{ImportRequest::TIMEOUT.inspect}"

    Imports::Settlement.fail!(import_request, reason(import_request))
    mark_course_failed(import_request)
  end

  private

  # Prefer what the pipeline actually reported: "Word translation count mismatch"
  # tells the user (and us) far more than "timed out", and the pipeline keeps
  # posting its failures to the callback even though nothing blocks on them any
  # more.
  def reason(import_request)
    failure = import_request.create_song_progress&.pipeline_errors&.last
    message = failure && failure["error_message"].presence
    return "Import timed out after #{ImportRequest::TIMEOUT.inspect}." if message.nil?

    "#{failure['step']}: #{message}"
  end

  # Only a course nobody has managed to publish. A course that is already live
  # in another language must not be knocked back to `error` because one
  # translation ran out of time.
  #
  # Status only — Imports::Settlement.fail! above has already notified the user
  # who was waiting on this request.
  def mark_course_failed(import_request)
    course = import_request.course
    return if course.nil? || course.published? || course.error?

    course.error!
  rescue => e
    Rails.logger.error "Failed to mark course #{import_request.course_id} as errored: #{e.message}"
  end
end
