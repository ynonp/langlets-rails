module Api
  module V1
    # The share extension needs the balance before it offers to import, and it
    # can't read the web session. Server-side balance, one source of truth for the
    # app, the extension and the web.
    class CreditsController < BaseController
      before_action -> { doorkeeper_authorize! :"credits:read" }

      def show
        render json: { balance: current_resource_owner.credit_balance }
      end
    end
  end
end
