class Tag < ApplicationRecord
  has_many :course_tags, dependent: :destroy
  has_many :courses, through: :course_tags
  
  validates :name, presence: true, uniqueness: true
  
  scope :used_in_playlist, ->(playlist) {
    joins(courses: :playlists)
      .where(playlists: { id: playlist.id })
      .distinct
      .order(:name)
  }
end