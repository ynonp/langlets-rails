class CourseLesson < ApplicationRecord
  belongs_to :course
  belongs_to :lesson
end
