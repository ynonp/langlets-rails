# Preview all emails at http://localhost:3000/rails/mailers/course_mailer
class CourseMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/course_mailer/creation_complete
  def creation_complete
    CourseMailer.creation_complete
  end

  # Preview this email at http://localhost:3000/rails/mailers/course_mailer/creation_failed
  def creation_failed
    CourseMailer.creation_failed
  end
end
