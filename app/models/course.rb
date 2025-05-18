class Course < ApplicationRecord
  has_many :course_lessons, -> { order(:order) }, dependent: :destroy
  has_many :lessons, -> {
    select('lessons.*, course_lessons.name AS course_lesson_name, course_lessons.order')
      .order('course_lessons.order')
  }, through: :course_lessons, dependent: :destroy
end
