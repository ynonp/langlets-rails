module Admin
  class ChannelsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin

    def index
      @channels = Channel.includes(:user).order(created_at: :desc)
      @channel = Channel.new
    end

    def create
      @channel = current_user.channels.new(channel_params.merge(default: false))
      @channel.visibility = :public
      @channel.slug = unique_slug(@channel.name)
      @channel.save!
      redirect_to admin_channels_path, notice: t("channels.admin.created")
    rescue ActiveRecord::RecordInvalid
      @channels = Channel.includes(:user).order(created_at: :desc)
      flash.now[:alert] = t("channels.admin.create_failed")
      render :index, status: :unprocessable_entity
    end

    def update
      channel = Channel.find(params[:id])
      channel.update!(name: channel_params[:name]) if channel_params[:name].present?
      channel.change_visibility!(channel_params[:visibility], actor: current_user)
      redirect_to admin_channels_path, notice: t("channels.admin.updated")
    end

    private

    def require_admin
      raise ActiveRecord::RecordNotFound unless current_user.admin?
    end

    def channel_params
      params.require(:channel).permit(:name, :visibility)
    end

    def unique_slug(name)
      base = name.to_s.parameterize.presence || "channel"
      candidate = base
      counter = 2
      while Channel.exists?(slug: candidate)
        candidate = "#{base}-#{counter}"
        counter += 1
      end
      candidate
    end
  end
end
