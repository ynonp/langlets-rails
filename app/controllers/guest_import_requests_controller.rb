class GuestImportRequestsController < ApplicationController
  PENDING_VIDEO_COOKIE = :pending_video_url

  def create
    video_url = VideoSource.loose_canonical(params[:url].to_s.strip)

    if video_url.blank?
      return redirect_to root_path, alert: "That doesn't look like a video link. Paste a YouTube or TikTok link."
    end

    cookies.encrypted[PENDING_VIDEO_COOKIE] = {
      value: video_url,
      expires: Time.zone.now + 30.minutes,
      httponly: true,
      same_site: :lax
    }

    redirect_to new_user_registration_path
  end
end
