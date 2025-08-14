class Tag < ApplicationRecord
  has_many :course_tags, dependent: :destroy
  has_many :courses, through: :course_tags
  
  validates :name, presence: true, uniqueness: true
  
  scope :used_in_learning_path, ->(learning_path) {
    joins(courses: :learning_paths)
      .where(learning_paths: { id: learning_path.id })
      .distinct
      .order(:name)
  }
end