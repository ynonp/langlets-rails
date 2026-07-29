class ChannelInvitationsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_channel, only: :create

  def index
    email = Channel.normalize_email(current_user.email)
    @invitations = ChannelInvitation.pending.valid_now
      .where("invitee_id = :id OR email = :email", id: current_user.id, email: email)
      .includes(channel: :user).order(created_at: :desc)
  end

  def show
    @invitation = ChannelInvitation.find_by_token(params[:token]) || raise(ActiveRecord::RecordNotFound)
    raise ActiveRecord::RecordNotFound unless @invitation.pending? && @invitation.expires_at > Time.zone.now
  end

  def create
    emails = params.require(:emails).to_s.split(/[\s,;]+/).filter_map(&:presence).uniq
    emails.each { |email| @channel.invite!(email: email, inviter: current_user) }
    redirect_to profile_path, notice: t("channels.invitations.sent")
  rescue Channel::UnauthorizedTransition, Channel::NotShared
    raise ActiveRecord::RecordNotFound
  rescue ActiveRecord::RecordInvalid
    redirect_to profile_path, alert: t("channels.invitations.invalid")
  end

  def accept
    invitation = invitation_from_params
    invitation.accept!(current_user)
    redirect_to channel_path(invitation.channel.slug), notice: t("channels.invitations.accepted")
  end

  def decline
    invitation = invitation_from_params
    invitation.decline!(current_user)
    redirect_to invitations_path, notice: t("channels.invitations.declined")
  end

  def revoke
    invitation = managed_invitation
    invitation.revoke!(current_user)
    redirect_to profile_path, notice: t("channels.invitations.revoked")
  end

  def resend
    invitation = managed_invitation
    invitation.resend!(current_user)
    redirect_to profile_path, notice: t("channels.invitations.resent")
  end

  private

  def load_channel
    @channel = Channel.find_by!(slug: params[:channel_slug])
  end

  def invitation_from_params
    invitation = if params[:token].present?
      ChannelInvitation.find_by_token(params[:token])
    else
      ChannelInvitation.find_by(id: params[:id])
    end
    invitation || raise(ActiveRecord::RecordNotFound)
  end

  def managed_invitation
    invitation = ChannelInvitation.find(params[:id])
    unless current_user.admin? || invitation.channel.user_id == current_user.id
      raise ActiveRecord::RecordNotFound
    end
    invitation
  end
end
