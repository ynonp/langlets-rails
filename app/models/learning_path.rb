class LearningPath < ApplicationRecord
  has_many :courses_learning_paths, dependent: :destroy
  has_many :courses, through: :courses_learning_paths

  scope :published, -> { where(published: true) }

  def cover_image_url
    first_course = courses.first
    return nil unless first_course&.main_media_url.present?

    Medium.new(url: first_course.main_media_url).thumbnail_url
  end
end
