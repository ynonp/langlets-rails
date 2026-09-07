module Admin
  class ProspectsController < BaseController
    def index
      @prospect_count = Prospect.count
      @activated_count = Prospect.where.not(activated_at: nil).count
      @prospects = paginate(Prospect.includes(:course).order(created_at: :desc, id: :desc))
    end
  end
end
