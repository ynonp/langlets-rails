class LessonUser < ApplicationRecord
  belongs_to :lesson
  belongs_to :user

  validates :lesson_id, uniqueness: { scope: :user_id }

  # Completing a lesson is the signal that the user is actively working through a
  # course, which is what orders Home's "Keep it going" list.
  after_create_commit :touch_enrollment

  private

  # Practising a course you were never enrolled in — a direct link, a learning
  # path — enrolls you in it. Otherwise the course you're part-way through would
  # be missing from Home.
  def touch_enrollment
    course_id = lesson&.course_id
    return if course_id.blank?

    enrollment = Enrollment.find_or_initialize_by(user_id: user_id, course_id: course_id)
    enrollment.source = :library if enrollment.new_record?
    enrollment.last_practiced_at = Time.zone.now
    enrollment.save!
  rescue ActiveRecord::RecordNotUnique
    # Raced with another completion for the same course; it created the row, so
    # just move the timestamp forward.
    Enrollment.where(user_id: user_id, course_id: course_id)
              .update_all(last_practiced_at: Time.zone.now)
  end
end
