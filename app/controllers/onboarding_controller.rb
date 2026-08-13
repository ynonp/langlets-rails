class OnboardingController < ApplicationController
  layout "onboarding"

  skip_before_action :require_authentication_for_native_app, only: [ :welcome, :video, :language ]
  before_action :redirect_web_browsers, only: [ :welcome, :video, :language ]

  def welcome
  end

  def video
    @homepage_videos = HomepageVideos.for_page
  end

  def language
    redirect_to app_home_path
  end

  def redirect_web_browsers
    return if native_app?
    redirect_to root_path
  end
end
