class CourseMailer < ApplicationMailer
  def creation_complete(course)
    @course = course
    @user = course.user
    
    mail(
      to: @user.email,
      subject: "Your course '#{@course.name}' is ready!"
    )
  end

  def creation_failed(course, error)
    @course = course
    @user = course.user

    # `error` may be an Exception (preferred) or a plain message string.
    if error.is_a?(Exception)
      @error_message = error.message
      @error_class = error.class.name
      @backtrace = Array(error.backtrace).first(20)
      @error_cause = error.cause
    else
      @error_message = error.to_s
      @error_class = nil
      @backtrace = []
      @error_cause = nil
    end

    @failed_at = Time.current

    mail(
      to: @user.email,
      subject: "Course creation failed for '#{@course.name}'"
    )
  end
end
