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

    head :ok
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue JSON::ParserError, KeyError, ProgressPatch::InvalidOp => e
    render status: :unprocessable_entity, json: { error: e.message }
  end
end
