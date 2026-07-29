class ChannelInvitationMailer < ApplicationMailer
  def invite
    @invitation = params[:invitation]
    @token = params[:token]
    mail to: @invitation.email,
      subject: I18n.t("channels.mailer.invite.subject", channel: @invitation.channel.name)
  end
end
