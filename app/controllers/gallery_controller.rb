class GalleryController < ApplicationController
  PER_PAGE = 16
  CONTENT_TYPES = %w[playlists].freeze
  IMPORT_FILTERS = UserImportFiltering::IMPORT_FILTERS

  def index
    @daily_vocab_language = if user_signed_in?
      current_user.daily_vocab_review_language(current_language_code)&.iso_name
    end
    @daily_vocab_streak = ActivityLog.current_streak_for_user(current_user) if @daily_vocab_language
    @search = params[:search].to_s.strip
    @import_filter = IMPORT_FILTERS.include?(params[:imports]) && user_signed_in? ? params[:imports] : nil
    @available_import_filters = user_signed_in? ? current_user.available_import_filters : []
    @import_filter = nil unless @available_import_filters.include?(@import_filter)
    @selected_types = Array(params[:types]).intersection(CONTENT_TYPES)
    @selected_languages = Language.where(iso_name: Array(params[:languages]).compact_blank).to_a
    @languages = gallery_languages
    @page = [ params[:page].to_i, 1 ].max

    visible_courses = gallery_courses
    course_scope = filtered_courses(visible_courses)
    playlist_scope = filtered_playlists(visible_courses)
    @import_requests = gallery_import_requests
    course_scope, playlist_scope = apply_import_filter(course_scope, playlist_scope)
    course_scope = course_scope.none if only_selected?("playlists")
    playlist_scope = playlist_scope.none if only_selected?("courses")
    @import_requests = [] if only_selected?("playlists")

    content_count = course_scope.count + playlist_scope.count
    @total_count = content_count + @import_requests.size
    @total_pages = (content_count.to_f / PER_PAGE).ceil
    @page = @total_pages if @total_pages.positive? && @page > @total_pages

    rows = mixed_page(course_scope, playlist_scope)
    hydrate_entries(rows)
    @import_requests = [] if @page > 1

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def gallery_import_requests
    return [] unless user_signed_in?

    scope = current_user.import_requests_for_filter(@import_filter).recent_first.includes(:course)

    if @selected_languages.any?
      scope = scope.where(clip_language: @selected_languages.map(&:english_name))
    end

    if @search.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@search.downcase)}%"
      scope = scope.where("LOWER(title) LIKE :pattern OR LOWER(youtube_url) LIKE :pattern", pattern: pattern)
    end

    scope.limit(50).to_a
  end

  def apply_import_filter(course_scope, playlist_scope)
    case @import_filter
    when "failed", "pending"
      [course_scope.none, playlist_scope.none]
    when "my_imports"
      [course_scope.where(id: current_user.ready_imported_course_ids), playlist_scope.none]
    else
      [course_scope, playlist_scope]
    end
  end

  def gallery_languages
    Language.where(
      id: gallery_visible_courses.select(:language_id)
    ).order(:english_name)
  end

  def gallery_courses
    scope = gallery_visible_courses
    @selected_languages.any? ? scope.where(language: @selected_languages) : scope
  end

  def only_selected?(type)
    @selected_types.one? && @selected_types.first == type
  end

  def filtered_courses(scope)
    if @search.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@search.downcase)}%"
      scope = scope.where(
        "LOWER(courses.name) LIKE :pattern OR EXISTS (" \
        "SELECT 1 FROM course_translations gallery_translations " \
        "WHERE gallery_translations.course_id = courses.id " \
        "AND gallery_translations.language_id = :language_id " \
        "AND LOWER(gallery_translations.name) LIKE :pattern)",
        pattern: pattern,
        language_id: Current.translation_language_id
      )
    end

    scope
  end

  def filtered_playlists(visible_courses)
    scope = Playlist.visible_to(current_user)
                    .where(id: Playlist.joins(:courses).merge(visible_courses).select(:id))

    if @search.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@search.downcase)}%"
      scope = scope.where("LOWER(playlists.name) LIKE :pattern OR LOWER(COALESCE(playlists.description, '')) LIKE :pattern", pattern: pattern)
    end

    scope
  end

  def mixed_page(course_scope, playlist_scope)
    course_sql = course_scope.reselect("'Course' AS item_type, courses.id, courses.created_at").to_sql
    playlist_sql = playlist_scope.reselect("'Playlist' AS item_type, playlists.id, playlists.created_at").to_sql
    offset = (@page - 1) * PER_PAGE
    sql = <<~SQL.squish
      SELECT item_type, id, created_at
      FROM ((#{course_sql}) UNION ALL (#{playlist_sql})) gallery_items
      ORDER BY created_at DESC, item_type ASC, id DESC
      LIMIT #{PER_PAGE} OFFSET #{offset}
    SQL

    ApplicationRecord.connection.select_all(sql).to_a
  end

  def hydrate_entries(rows)
    course_ids = rows.filter_map { |row| row["id"] if row["item_type"] == "Course" }
    playlist_ids = rows.filter_map { |row| row["id"] if row["item_type"] == "Playlist" }

    courses = Course.where(id: course_ids)
                    .includes(:language, :localized_translation)
                    .index_by { |course| course.id.to_s }
    lesson_counts = Lesson.where(course_id: course_ids).group(:course_id).count
    courses.each_value do |course|
      count = lesson_counts[course.id] || 0
      course.define_singleton_method(:lessons_count) { count }
    end

    playlists = Playlist.where(id: playlist_ids).includes(:courses).index_by { |playlist| playlist.id.to_s }
    visible_courses = gallery_visible_courses
    visible_courses = visible_courses.where(language: @selected_languages) if @selected_languages.any?
    clip_counts = CoursesPlaylist.where(playlist_id: playlist_ids, course_id: visible_courses.select(:id))
                                 .group(:playlist_id).count
    playlists.each_value do |playlist|
      count = clip_counts[playlist.id] || 0
      playlist.define_singleton_method(:visible_clip_count) { count }
    end

    @entries = rows.filter_map do |row|
      row["item_type"] == "Course" ? courses[row["id"].to_s] : playlists[row["id"].to_s]
    end
  end

  def gallery_visible_courses
    ChannelContentQuery.courses_listed_to(current_user).published.ready_in(Current.translation_language)
  end
end
