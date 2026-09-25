module Api::V1::Native
  class InvitationsController < BaseController
    def index
      render json: page(invitations.includes(:channel).order(id: :desc)) { |row|
        { id: row.id, name: row.channel.name, expires_at: row.expires_at.iso8601 }
      }
    end
    def update
      invitation = invitations.find(params[:id])
      case params.require(:decision)
      when "accept" then invitation.accept!(user)
      when "decline" then invitation.decline!(user)
      else raise ArgumentError, "Unknown decision"
      end
      head :no_content
    rescue Channel::UnauthorizedTransition
      raise ActiveRecord::RecordNotFound
    end
    private
    def invitations
      ChannelInvitation.pending.valid_now.where("invitee_id = :id OR email = :email", id: user.id, email: Channel.normalize_email(user.email))
    end
  end
end
