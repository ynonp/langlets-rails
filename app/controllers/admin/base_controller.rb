module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin
    layout "admin"

    private

    def require_admin
      head :forbidden unless current_user.admin?
    end

    def paginate(scope)
      @page = [ params[:page].to_i, 1 ].max
      @total = scope.count
      @pages = [ (@total / 30.0).ceil, 1 ].max
      @page = [ @page, @pages ].min
      scope.limit(30).offset((@page - 1) * 30)
    end

    def search_term
      @query = params[:q].to_s.strip.first(200)
      "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
    end
  end
end
