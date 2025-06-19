class LearningPath < ApplicationRecord
  has_many :courses_learning_paths, dependent: :destroy
  has_many :courses, through: :courses_learning_paths
  
  scope :published, -> { where(published: true) }
end
