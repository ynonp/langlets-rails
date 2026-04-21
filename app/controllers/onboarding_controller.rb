class OnboardingController < ApplicationController
  skip_before_action :require_authentication_for_native_app, only: [:language]
  skip_before_action :require_language_for_native_app, only: [:language]

  def language
    @languages = Language.all.order(:english_name)
  end
end
