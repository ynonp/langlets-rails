# Receives progress updates from the Create Song pipeline service
# (pipeline/README.md). Each request is a batch of patch operations against
# one record's data blob, HMAC-signed with the shared secret.
#
# Patches are applied under a row lock: the pipeline's branches run
# concurrently and their callbacks can land at the same time — without the
# lock two load-mutate-save cycles would silently drop each other's ops.
class PipelineCallbacksController < ActionController::API
  def update
    return head :unauthorized unless PipelineHmac.verify_request(request)

    progress = CreateSongProgress.find(params[:id])
    ops = JSON.parse(request.raw_post).fetch("ops")

    progress.with_lock do
      progress.data ||= {}
      ProgressPatch.apply_all(progress.data, ops)
      progress.save!
    end

    finalize_later(progress)

    head :ok
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue JSON::ParserError, KeyError, ProgressPatch::InvalidOp => e
    render status: :unprocessable_entity, json: { error: e.message }
  end

  private

  # There is no "run finished" callback to wait for — the pipeline streams
  # patches and stops — so completion is re-derived here, after every batch.
  #
  # The gate is deliberately the cheap half of that question: current_step reads
  # keys already in memory, while the per-language check and the publish itself
  # cost queries and a course rebuild. A run sends many batches and only its last
  # few can leave the blob looking finished, so this enqueues a handful of jobs
  # per run rather than one per patch. Anything it double-enqueues is harmless —
  # Imports::Finalizer is idempotent.
  def finalize_later(progress)
    return unless progress.pipeline_complete? || progress.pipeline_errors.any?

    FinalizeImportsJob.perform_later(progress.id)
  end
end
