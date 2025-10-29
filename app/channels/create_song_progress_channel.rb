class CreateSongProgressChannel < ApplicationCable::Channel
  def subscribed
    progress = CreateSongProgress.find(params[:id])
    stream_for progress
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
