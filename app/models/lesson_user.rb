class LessonUser < ApplicationRecord
  belongs_to :lesson
  belongs_to :user
  
  validates :lesson_id, uniqueness: { scope: :user_id }
end
