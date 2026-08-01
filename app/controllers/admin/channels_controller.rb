module Admin
  class ChannelsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin

    def index
      @channels = manageable_channels
      @channel = Channel.new
    end

    def create
      @channel = current_user.channels.new(channel_params.merge(default: false))
      @channel.visibility = :public
      @channel.slug = unique_slug(@channel.name)
      @channel.save!
      redirect_to admin_channels_path, notice: t("channels.admin.created")
    rescue ActiveRecord::RecordInvalid
      @channels = manageable_channels
      flash.now[:alert] = t("channels.admin.create_failed")
      render :index, status: :unprocessable_entity
    end

    def update
      channel = manageable_channels.find(params[:id])
      channel.update!(name: channel_params[:name]) if channel_params[:name].present?
      channel.change_visibility!(channel_params[:visibility], actor: current_user)
      redirect_to admin_channels_path, notice: t("channels.admin.updated")
    end

    private

    def require_admin
      raise ActiveRecord::RecordNotFound unless current_user.admin?
    end

    # This screen exists to manage public Channels. `Channel` is an STI base
    # class, so an unscoped query here would list — and offer to edit — every
    # subscriber's private Pro library.
    def manageable_channels
      Channel.where(type: nil).includes(:user).order(created_at: :desc)
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
