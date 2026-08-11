class GuestImportRequestsController < ApplicationController
  PENDING_VIDEO_COOKIE = :pending_video_url
  EVALUATION_SIGNUP_COOKIE = :evaluation_signup_token

  def create
    raw_url = params[:url].to_s.strip
    video_url = VideoSource.loose_canonical(raw_url)

    if video_url.blank?
      return redirect_to(native_app? ? onboarding_video_path : root_path,
                         alert: "That doesn't look like a video link. Paste a YouTube or TikTok link.")
    end

    admin = User.find_by!(email: User::ADMIN_EMAIL)
    translation_language = Current.translation_language.english_name
    clip_language = HomepageVideos.find_by_url(video_url)&.clip_language
    source_video_id = VideoSource.video_id(video_url)
    source = if source_video_id.present?
      admin.import_requests
           .where(guest_started: true, youtube_video_id: source_video_id, translation_language: translation_language)
           .where(status: [ :detecting, :queued, :importing, :ready ])
           .recent_first
           .first
    end
    source ||= Imports::Create.call(
      user: admin,
      url: video_url,
      clip_language: clip_language,
      translation_language: translation_language,
      guest_started: true
    ).import_request
    evaluation_signup = EvaluationSignup.create!(
      admin_import_request: source,
      initial_course: source.course,
      course: source.course,
      video_url: source.youtube_url,
      video_id: source.youtube_video_id,
      provider: VideoSource.provider(source.youtube_url),
      title: source.title,
      thumbnail_url: source.thumbnail_url,
      clip_language: source.clip_language || clip_language,
      translation_language: source.translation_language
    )
    store_pending(EVALUATION_SIGNUP_COOKIE, evaluation_signup.token, 1.day)

    redirect_to params[:authentication] == "login" ? new_user_session_path : new_user_registration_path
  rescue VideoSource::UnavailableVideo
    redirect_to try_path(url: raw_url), alert: "That video is unavailable. Try another one."
  end

  private

  def store_pending(name, value, ttl)
    cookies.encrypted[name] = {
      value: value,
      expires: Time.zone.now + ttl,
      httponly: true,
      same_site: :lax
    }
  end
end
