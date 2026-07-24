module App
  # Screen 02. Everything the community has imported, not just this user's.
  class LibraryController < BaseController
    def show
      @query = params[:q].to_s.strip
      @courses = search(published_scope).limit(60).to_a
      @lesson_counts = Lesson.where(course_id: @courses.map(&:id)).group(:course_id).count
      @enrolled_course_ids = current_user.enrollments.where(course_id: @courses.map(&:id)).pluck(:course_id).to_set
    end

    private

    def published_scope
      scope = Course.published.ready_in(Current.translation_language).includes(:language, { course_translations: :language })
      language = Language.find_by(iso_name: current_language_code) if current_language_code.present?
      language ? scope.where(language: language) : scope
    end

    def search(scope)
      return scope.order(created_at: :desc) if @query.blank?

      # The spec says search also takes a pasted link, which is how someone
      # checks whether a video is already in the Library before spending a credit.
      if (video_id = VideoSource.video_id(@query))
        return scope.where(youtube_video_id: video_id)
      end

      scope.where("courses.name ILIKE ?", "%#{sanitize_sql_like(@query)}%").order(created_at: :desc)
    end

    def sanitize_sql_like(string)
      ActiveRecord::Base.sanitize_sql_like(string)
    end
  end
end
