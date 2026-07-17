class Playlist < ApplicationRecord
  # nil user = system playlist: curated by admins, shown to everyone.
  # A user's own playlists are visible and editable only by that user.
  belongs_to :user, optional: true

  has_many :courses_playlists, dependent: :destroy
  has_many :courses, through: :courses_playlists

  scope :published, -> { where(published: true) }
  scope :system_playlists, -> { where(user_id: nil) }
  scope :owned_by, ->(user) { where(user: user) }

  # What a visitor can browse: published system playlists, plus their own.
  scope :visible_to, ->(user) {
    if user
      system_playlists.published.or(owned_by(user))
    else
      system_playlists.published
    end
  }

  def system?
    user_id.nil?
  end

  # System playlists stay reachable by URL whether or not they're published
  # (matching the old learning-path behavior); personal playlists are only
  # visible to their owner (and admins, so they can moderate).
  def visible_to?(user)
    return true if system?
    user.present? && (user.id == user_id || user.admin?)
  end

  def cover_image_url
    first_course = courses.first
    return nil unless first_course&.main_media_url.present?

    Medium.new(url: first_course.main_media_url).thumbnail_url
  end

  def destroy_with_all_courses
    courses.each do |course|
      # Read through the course's own lessons rather than looking the medium up
      # by URL: one URL now has a medium per language pair, so a URL lookup could
      # return another pair's medium and destroy the wrong course's phrases.
      # Captured before course.destroy, which cascades the lessons away.
      medium = course.medium
      lesson_ids = course.lessons.pluck(:id)
      ActivityLog.where(lesson_id: lesson_ids).destroy_all
      course.destroy
      medium&.phrases&.destroy_all
      medium&.destroy
    end
    destroy
  end
end
