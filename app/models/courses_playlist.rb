class CoursesPlaylist < ApplicationRecord
  belongs_to :course
  belongs_to :playlist
end
