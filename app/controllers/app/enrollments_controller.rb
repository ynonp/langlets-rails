module App
  # "+ Learn this" — puts a Library course on the user's Home. Free: the content
  # is already imported, so there's no AI work to pay for.
  class EnrollmentsController < BaseController
    def create
      course = Course.published.find_by!(slug: params[:course_slug])

      enrollment = Enrollment.find_or_initialize_by(user: current_user, course: course)
      enrollment.source = :library if enrollment.new_record?
      enrollment.save!

      redirect_back fallback_location: app_library_path,
                    notice: "Added to your Home."
    rescue ActiveRecord::RecordNotUnique
      redirect_back fallback_location: app_library_path
    end
  end
end
