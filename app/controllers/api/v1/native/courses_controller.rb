module Api::V1::Native
  class CoursesController < BaseController
    def index
      scope = if params[:enrolled] == "true"
        ChannelContentQuery.courses_visible_to(user).where(id: user.enrollments.select(:course_id))
      else
        ChannelContentQuery.courses_listed_to(user)
      end
      scope = scope.published.includes(:language, :localized_translation, :course_translations, lessons: [ :localized_translation, :course ])
      scope = scope.where(language: Language.find_by!(iso_name: params[:language])) if params[:language].present?
      if params[:q].present?
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(200))}%"
        scope = scope.where("courses.name ILIKE ?", pattern)
      end
      scope = scope.where(id: user.ready_imported_course_ids) if params[:filter] == "my_imports"
      scope = scope.joins(:enrollments).where(enrollments: { user_id: user.id }).order(Arel.sql("enrollments.last_practiced_at DESC NULLS LAST")) if params[:enrolled] == "true"
      render json: page(scope.order(created_at: :desc, id: :desc)) { |row| serializer.course(row) }
    end

    def show
      render json: serializer.course(readable_course)
    end

    def download
      course = readable_course
      render json: { course: serializer.course(course), phrases: serializer.course_phrases(course), lessons: course.lessons.order(:order, :id).map { |row| serializer.lesson(row) } }
    end

    def action
      course = readable_course
      user.with_lock do
        case params.require(:operation)
        when "enroll"
          user.enrollments.create_or_find_by!(course: course) { |row| row.source = :library }
        when "share"
          user.share_channel.channel_items.create_or_find_by!(course: course) { |row| row.published_at = Time.zone.now }
        when "unshare"
          user.share_channel.unpublish!(course)
        when "translate"
          CourseTranslations::Request.call(course: course, language: user.native_language)
        when "mark_done"
          course.lessons.each { |row| user.lesson_users.find_or_create_by!(lesson: row) }
        when "reset", "delete"
          if params[:operation] == "delete"
            raise ActiveRecord::RecordNotFound unless user.owns_publication_of?(course)
            user.provision_default_channel!.unpublish!(course)
            user.pro_channel&.unpublish!(course)
          end
          lesson_ids = course.lessons.select(:id)
          user.activity_users.where(activity_id: Activity.where(lesson_id: lesson_ids).select(:id)).destroy_all
          user.lesson_users.where(lesson_id: lesson_ids).destroy_all
          user.activity_logs.where(lesson_id: lesson_ids).destroy_all
          user.enrollments.where(course: course).destroy_all
        else
          raise ArgumentError, "Unknown course operation"
        end
      end
      render json: { status: "ok", public_url: course_url(course, host: request.base_url) }
    end
  end
end
