module Admin
  class DashboardController < BaseController
    def index
      @users_count = User.count
      @channels_count = Channel.count
      @statuses = ImportRequest.group(:status).count
      @failures = ImportRequest.failed.includes(:user, :course).order(updated_at: :desc).limit(10)
    end
  end
end
