class CourseMailer < ApplicationMailer
  def creation_complete(course)
    @course = course
    @user = course.user
    
    mail(
      to: @user.email,
      subject: "Your course '#{@course.name}' is ready!"
    )
  end

  def creation_failed(course, error_message)
    @course = course
    @user = course.user
    @error_message = error_message
    
    mail(
      to: @user.email,
      subject: "Course creation failed for '#{@course.name}'"
    )
  end
end
