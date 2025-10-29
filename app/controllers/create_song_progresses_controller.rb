class CreateSongProgressesController < ApplicationController
  def show
    @progress = CreateSongProgress.find(params[:id])
    @course = Course.find_by(main_media_url: @progress.youtubeurl)
  end
end
