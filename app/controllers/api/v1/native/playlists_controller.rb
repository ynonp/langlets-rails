module Api::V1::Native
  class PlaylistsController < BaseController
    def index
      render json: page(Playlist.visible_to(user).order(id: :desc)) { |row| summary(row) }
    end

    def show
      row = Playlist.visible_to(user).find(params[:id])
      courses = row.courses.merge(ChannelContentQuery.courses_visible_to(user)).published
      render json: summary(row).merge(courses: page(courses.order(:id)) { |course| serializer.course(course) })
    end

    def create
      row = user.playlists.create!(name: params.require(:name).to_s.first(200), slug: SecureRandom.uuid, published: true)
      render json: summary(row), status: :created
    end

    def update
      row = user.playlists.find(params[:id])
      course = readable_course(params[:course_slug])
      if params[:included] == true
        row.courses << course unless row.courses.exists?(course.id)
      elsif params[:included] == false
        row.courses.delete(course)
      else
        raise ArgumentError, "included must be a boolean"
      end
      render json: summary(row)
    end

    def destroy
      user.playlists.find(params[:id]).destroy!
      head :no_content
    end

    private

    def summary(row)
      { id: row.id, name: row.name, description: row.description, owned: row.user_id == user.id }
    end
  end
end
