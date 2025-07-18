class CourseLike < ApplicationRecord
  belongs_to :user
  belongs_to :course

  # Ensure a user can only like a course once
  validates :user_id, uniqueness: { scope: :course_id }
end