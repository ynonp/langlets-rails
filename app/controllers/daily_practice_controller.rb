class DailyPracticeController < ApplicationController
  before_action :authenticate_user!

  def show
    redirect_to daily_challenge_path
  end
end
