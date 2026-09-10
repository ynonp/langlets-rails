class TryController < ApplicationController
  def show
    @video_url = VideoSource.loose_canonical(params[:url].to_s.strip)
    raise VideoSource::UnavailableVideo if @video_url.blank?

    @video = VideoSource.fetch(@video_url)
    @video_info = TryVideoInfo.for(@video)
  rescue VideoSource::UnavailableVideo
    redirect_to(native_app? ? onboarding_video_path : root_path,
                alert: I18n.t("imports.errors.unavailable"))
  end
end
