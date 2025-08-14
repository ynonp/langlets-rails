class CourseTag < ApplicationRecord
  belongs_to :course
  belongs_to :tag
end