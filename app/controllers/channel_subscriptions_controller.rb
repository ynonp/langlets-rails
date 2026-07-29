class ChannelSubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def destroy
    subscription = ChannelSubscription.includes(:channel).find(params[:id])
    unless current_user.admin? || subscription.channel.user_id == current_user.id
      raise ActiveRecord::RecordNotFound
    end
    subscription.destroy!
    redirect_to profile_path, notice: t("channels.members.removed")
  end
end
