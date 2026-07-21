# Runs Imports::Finalizer off the callback request. PipelineCallbacksController
# is on the pipeline's critical path — every patch it sends waits on our
# response — so building and publishing a course must not happen inside it.
#
# Enqueued only when the callback left the blob looking finished or failed, so
# this is a handful of jobs per run, not one per patch.
class FinalizeImportsJob < ApplicationJob
  queue_as :default

  def perform(create_song_progress_id)
    progress = CreateSongProgress.find_by(id: create_song_progress_id)
    return if progress.nil?

    Imports::Finalizer.call(progress)
  end
end
