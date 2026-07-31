module App
  # "+ Learn this" — puts a Library course on the user's Home. Free: the content
  # is already imported, so there's no AI work to pay for.
  class EnrollmentsController < BaseController
    def create
      # Scoped to what this user may read, so a slug alone cannot pull an
      # unreadable Course onto someone's Home. A miss 404s rather than 403s,
      # matching the rest of the read surface.
      course = ChannelContentQuery.courses_visible_to(current_user)
                                  .published
                                  .find_by!(slug: params[:course_slug])

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
