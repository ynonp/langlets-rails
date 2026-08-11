class SitemapsController < ApplicationController
  def show
    # Only what a logged-out visitor can browse. `published_courses` alone is a
    # pipeline status ("the build finished"), not a visibility rule, so it also
    # matches every user's personal import sitting in their private default
    # Channel. Scoping to the system Channel keeps private and unlisted public
    # courses out of Google, and
    # `ready_in` matches the homepage so a course whose English translation is
    # still processing is not indexed mid-build.
    @courses = ChannelContentQuery.listed_courses
      .published_courses
      .ready_in(Current.translation_language)
      .includes(:language)
      .order(updated_at: :desc)
    @playlists = Playlist.system_playlists.published.order(updated_at: :desc)
    @static_pages = [
      { path: root_path, priority: 1.0, changefreq: "daily" },
      { path: home_privacy_path, priority: 0.3, changefreq: "monthly" },
      { path: home_terms_path, priority: 0.3, changefreq: "monthly" }
    ]

    respond_to do |format|
      format.xml { render layout: false }
    end
  end
end
