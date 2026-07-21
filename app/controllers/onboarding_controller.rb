class OnboardingController < ApplicationController
  layout "onboarding"

  skip_before_action :require_authentication_for_native_app, only: [:language]
  skip_before_action :require_language_for_native_app, only: [ :welcome, :language ]
  before_action :redirect_web_browsers, only: [ :welcome, :language ]

  def welcome
    @return_to = params[:returnto].presence || app_home_path
  end

  def language
    @languages = Language.all.order(:english_name)
    @return_to = params[:returnto].presence || params[:return_to].presence
  end

  def redirect_web_browsers
    return if native_app?
    redirect_to root_path
  end

  private

  def language_redirect_url(iso)
    base = @return_to || root_path
    uri = URI.parse(base)
    query = Rack::Utils.parse_nested_query(uri.query)
    query["lang"] = iso
    uri.query = Rack::Utils.build_nested_query(query).presence
    uri.to_s
  end
  helper_method :language_redirect_url
end
