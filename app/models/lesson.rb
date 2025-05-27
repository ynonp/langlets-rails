class Lesson < ApplicationRecord
  belongs_to :medium
  belongs_to :course, optional: true
  has_many :activities, dependent: :destroy
  has_timestamp [ :start_timestamp, :end_timestamp ]
  include FriendlyName

  def create_activities
    intro = Activities::WatchVideoActivity.create!(lesson: self, order: 1)
    intro.phrases = medium.phrases.ordered_by_timestamp.between_durations(self.start_timestamp_seconds, self.end_timestamp_seconds)

    learn1 = Activities::MatchPhrasesActivity.create!(lesson: self, order: 2)
    learn1.phrases = medium.phrases.ordered_by_timestamp.between_durations(self.start_timestamp_seconds, self.end_timestamp_seconds).limit(5)    

    learn2 = Activities::SortPhrasesActivity.create!(lesson: self, order: 3)
    learn2.phrases = medium.phrases.ordered_by_timestamp.between_durations(self.start_timestamp_seconds, self.end_timestamp_seconds).limit(5)

    self.activities = [
      intro,
      learn1,
      learn2
    ]
  end
end
