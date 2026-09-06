module Admin
  class ChannelsController < BaseController
    def index
      term = search_term
      scope = Channel.includes(:user).order(created_at: :desc, id: :desc)
      scope = scope.joins(:user).where("channels.name ILIKE ? OR channels.slug ILIKE ? OR users.email ILIKE ?", term, term, term) if @query.present?
      @channels = paginate(scope).to_a
      @item_counts = ChannelItem.where(channel_id: @channels.map(&:id)).group(:channel_id).count
    end

    def show
      @channel = Channel.includes(:user).find(params[:id])
      @items = paginate(@channel.channel_items.includes(course: :language).order(published_at: :desc, id: :desc))
    end
  end
end
