class CourseStar < ApplicationRecord
  belongs_to :user
  belongs_to :course
  
  # Ensure uniqueness at the model level as well
  validates :user_id, uniqueness: { scope: :course_id }
end
