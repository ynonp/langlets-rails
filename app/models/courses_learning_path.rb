class CoursesLearningPath < ApplicationRecord
  belongs_to :course
  belongs_to :learning_path
end
