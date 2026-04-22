class OnboardingController < ApplicationController
  skip_before_action :require_authentication_for_native_app, only: [:language]
  skip_before_action :require_language_for_native_app, only: [:language]

  def language
    @languages = Language.all.order(:english_name)
    @return_to = params[:returnto]
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
