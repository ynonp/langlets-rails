class ChannelsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_channel

  def show
    raise ActiveRecord::RecordNotFound unless @channel.discoverable_by?(current_user)

    @invitation = pending_invitation unless @channel.readable_by?(current_user)
    @items = if @channel.readable_by?(current_user)
      ChannelContentQuery.new(user: current_user).items.where(channel_id: @channel.id).limit(60)
    else
      ChannelItem.none
    end
    course_ids = @items.map(&:course_id)
    @lesson_counts = Lesson.where(course_id: course_ids).group(:course_id).count
    @enrolled_course_ids = current_user.enrollments.where(course_id: course_ids).pluck(:course_id).to_set
  end

  def unsubscribe
    subscription = @channel.channel_subscriptions.find_by!(user: current_user)
    subscription.destroy!
    redirect_to app_home_path, notice: t("channels.flash.unsubscribed")
  end

  private

  def load_channel
    @channel = Channel.find_by!(slug: params[:slug])
  end

  def pending_invitation
    @channel.channel_invitations.pending.valid_now.find_by(
      "invitee_id = :id OR email = :email",
      id: current_user.id, email: Channel.normalize_email(current_user.email)
    )
  end
end
