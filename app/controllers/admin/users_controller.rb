module Admin
  class UsersController < BaseController
    def index
      term = search_term
      scope = User.order(created_at: :desc, id: :desc)
      scope = scope.where("email ILIKE ?", term) if @query.present?
      @users = paginate(scope).to_a
      @pro_user_ids = Subscription.entitling.where(user_id: @users.map(&:id)).distinct.pluck(:user_id)
    end

    def grant_pro
      user = User.find(params[:id])
      user.with_lock { user.pro! unless user.pro? }
      redirect_to admin_users_path(q: user.email), notice: "#{user.email} has Pro access.", status: :see_other
    end
  end
end
