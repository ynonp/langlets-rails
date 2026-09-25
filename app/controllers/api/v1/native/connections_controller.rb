module Api::V1::Native
  class ConnectionsController < BaseController
    def index
      render json: page(user.oauth_access_tokens.where(revoked_at: nil).includes(:application).order(id: :desc)) { |row|
        { id: row.id, name: row.application&.name || "Application", scopes: row.scopes.to_s,
          created_at: row.created_at.iso8601, current: row.id == doorkeeper_token.id }
      }
    end
    def destroy
      user.oauth_access_tokens.find(params[:id]).revoke
      head :no_content
    end
  end
end
