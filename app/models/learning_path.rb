class LearningPath < ApplicationRecord
  has_many :courses_learning_paths, dependent: :destroy
  has_many :courses, through: :courses_learning_paths

  scope :published, -> { where(published: true) }

  def cover_image_url
    first_course = courses.first
    return nil unless first_course&.main_media_url.present?

    Medium.new(url: first_course.main_media_url).thumbnail_url
  end

  def destroy_with_all_courses
    courses.each do |course|
      url = course.main_media_url
      medium = Medium.find_by(url:)
      lesson_ids = course.lessons.pluck(:id)
      ActivityLog.where(lesson_id: lesson_ids).destroy_all
      course.destroy
      medium&.phrases&.destroy_all
      medium&.destroy
    end
    destroy
  end
end
