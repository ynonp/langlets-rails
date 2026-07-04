module Settings
  # Lists the OAuth tokens issued for the current user (AI agents, CLI) and
  # lets them revoke a single token or disconnect an application entirely.
  class ConnectionsController < ApplicationController
    before_action :authenticate_user!

    def index
      tokens = Doorkeeper::AccessToken
        .where(resource_owner_id: current_user.id, revoked_at: nil)
        .includes(:application)
        .order(created_at: :desc)
        .reject(&:expired?)

      @connections = tokens.group_by(&:application)
    end

    def destroy
      token = Doorkeeper::AccessToken.find_by!(id: params[:id], resource_owner_id: current_user.id)
      token.revoke

      redirect_to settings_connections_path, notice: "Token revoked."
    end

    def revoke_application
      application = Doorkeeper::Application.find(params[:application_id])
      Doorkeeper::Application.revoke_tokens_and_grants_for(application.id, current_user)

      redirect_to settings_connections_path, notice: "#{application.name} disconnected."
    end
  end
end
