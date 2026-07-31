module App
  # Screen 02. Everything the community has imported, not just this user's.
  class LibraryController < BaseController
    FILTERS = (UserImportFiltering::IMPORT_FILTERS + %w[playlists]).freeze

    def show
      @query = params[:q].to_s.strip
      @filter = FILTERS.include?(params[:filter]) ? params[:filter] : nil
      @visible_items_scope = published_scope
      @languages = visible_languages
      @language = @languages.find { |language| language.iso_name == params[:language] }
      @has_playlists = current_user.playlists.exists?
      @available_import_filters = current_user.available_import_filters
      @filter = nil unless filter_available?
      @playlists = @filter == "playlists" ? visible_playlists : []
      @import_requests = filtered_import_requests
      @items = search(filtered_published_scope).limit(60).to_a
      @courses = @items.map(&:course)
      @lesson_counts = Lesson.where(course_id: @courses.map(&:id)).group(:course_id).count
      @enrolled_course_ids = current_user.enrollments.where(course_id: @courses.map(&:id)).pluck(:course_id).to_set

    end

    private

    def filtered_import_requests
      return [] if @filter == "playlists"

      scope = current_user.import_requests_for_filter(@filter).recent_first.includes(:course)
      scope = scope.where(clip_language: @language.english_name) if @language

      search_import_requests(scope).limit(50).to_a
    end

    def filtered_published_scope
      scope = case @filter
      when "failed", "pending"
        @visible_items_scope.none
      when "playlists"
        @visible_items_scope.none
      when "my_imports"
        @visible_items_scope.where(courses: { id: current_user.ready_imported_course_ids })
      else
        @visible_items_scope
      end

      @language ? scope.where(courses: { language_id: @language.id }) : scope
    end

    def published_scope
      ChannelContentQuery.new(user: current_user).items
    end

    def visible_languages
      Language.where(id: @visible_items_scope.reselect("courses.language_id")).order(:english_name).to_a
    end

    def visible_playlists
      scope = current_user.playlists.includes(courses: :language).order(created_at: :desc)
      return scope.to_a if @query.blank? || @filter != "playlists"

      pattern = "%#{sanitize_sql_like(@query)}%"
      scope.where("playlists.name ILIKE ?", pattern).to_a
    end

    def filter_available?
      return true if @filter.nil?
      return @has_playlists if @filter == "playlists"

      @available_import_filters.include?(@filter)
    end

    def search(scope)
      return scope.order(created_at: :desc) if @query.blank?

      # The spec says search also takes a pasted link, which is how someone
      # checks whether a video is already in the Library before spending a credit.
      if (video_id = VideoSource.video_id(@query))
        return scope.where(courses: { youtube_video_id: video_id })
      end

      pattern = "%#{sanitize_sql_like(@query)}%"
      scope.where("courses.name ILIKE :pattern OR channels.name ILIKE :pattern", pattern: pattern)
    end

    def search_import_requests(scope)
      return scope if @query.blank?

      if (video_id = VideoSource.video_id(@query))
        return scope.where(youtube_video_id: video_id)
      end

      pattern = "%#{sanitize_sql_like(@query)}%"
      scope.where("title ILIKE :pattern OR youtube_url ILIKE :pattern", pattern: pattern)
    end

    def sanitize_sql_like(string)
      ActiveRecord::Base.sanitize_sql_like(string)
    end
  end
end
