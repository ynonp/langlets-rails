module Api::V1::Native
  class ImportPreviewsController < BaseController
    def destroy
      row = user.import_requests.find(params[:id])
      row.with_lock do
        if row.queued?
          row.update!(status: :canceled)
        elsif row.failed? || row.ready?
          row.destroy!
        else
          return render_error(:import_in_progress, "This import is already being processed", :conflict)
        end
      end
      head :no_content
    end

    def show
      result = Imports::Preview.call(user: user, url: params.require(:url), clip_language: nil,
        translation_language: user.native_language.english_name)
      render json: { status: result.status, title: result.video.title, thumbnail_url: result.video.thumbnail_url,
        cost: result.cost, pro: user.pro?, credits: user.credit_balance,
        course_slug: result.course&.readable_by?(user) ? result.course.slug : nil }
    rescue VideoSource::UnavailableVideo, Imports::UnsupportedLanguage, Imports::VideoPreflight::TooLong
      render_error(:unavailable_video, "This video cannot be imported. Check that it is public, supported, and no longer than 25 minutes.", :unprocessable_entity)
    end
  end
end
