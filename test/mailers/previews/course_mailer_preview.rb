# Preview all emails at http://localhost:3000/rails/mailers/course_mailer
class CourseMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/course_mailer/creation_complete
  def creation_complete
    CourseMailer.creation_complete(Course.last)
  end

  # Preview this email at http://localhost:3000/rails/mailers/course_mailer/creation_failed
  def creation_failed
    error =
      begin
        raise "undefined method `each' for an instance of RuntimeError"
      rescue => e
        e
      end

    CourseMailer.creation_failed(Course.last, error)
  end
end
