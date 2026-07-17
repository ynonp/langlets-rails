class CoursePlaylistsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_course

  # GET /courses/:course_id/playlists
  # Returns the playlists this user can add courses to, plus whether this
  # course belongs to each. Used to refresh the "add to playlist" popup.
  # Admins manage the system playlists; everyone else sees their own.
  def index
    render json: { paths: serialized_playlists }
  end

  # POST /courses/:course_id/playlists
  # Either attaches an existing playlist (playlist_id) or creates a new one (name).
  # Any signed-in user may add any course to a playlist they own.
  def create
    playlist =
      if params[:name].present?
        Playlist.create!(
          name: params[:name].strip,
          published: true,
          slug: unique_slug(params[:name]),
          # Admin-created playlists are system playlists (visible to everyone),
          # matching how curation worked before playlists became per-user.
          user: current_user.admin? ? nil : current_user
        )
      else
        Playlist.find(params[:playlist_id])
      end

    authorize! :update, playlist
    CoursesPlaylist.find_or_create_by!(course: @course, playlist: playlist)

    render json: { path: serialize(playlist, member: true) }
  end

  # DELETE /courses/:course_id/playlists/:id
  def destroy
    playlist = Playlist.find(params[:id])
    authorize! :update, playlist
    CoursesPlaylist.where(course: @course, playlist: playlist).destroy_all
    render json: { path: serialize(playlist, member: false) }
  end

  private

  def set_course
    @course = Course.find_by(slug: params[:course_id]) || Course.find(params[:course_id])
  end

  def editable_playlists
    if current_user.admin?
      Playlist.system_playlists.or(Playlist.owned_by(current_user))
    else
      current_user.playlists
    end
  end

  def serialized_playlists
    member_ids = @course.playlist_ids.to_set
    editable_playlists.order(created_at: :desc).map do |playlist|
      serialize(playlist, member: member_ids.include?(playlist.id))
    end
  end

  def serialize(playlist, member:)
    {
      id: playlist.id,
      name: playlist.name.to_s,
      courses_count: playlist.courses.count,
      member: member
    }
  end

  def unique_slug(name)
    base = name.parameterize.presence || "playlist"
    slug = base
    counter = 1
    while Playlist.exists?(slug: slug)
      slug = "#{base}-#{counter}"
      counter += 1
    end
    slug
  end
end
