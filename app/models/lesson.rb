class Lesson < ApplicationRecord
  belongs_to :medium
  belongs_to :course, optional: true
  has_many :activities, dependent: :destroy
  has_timestamp [ :start_timestamp, :end_timestamp ]
  include FriendlyName

  has_many :lesson_users, dependent: :destroy
  has_many :users_completed, through: :lesson_users, source: :user

  # Add virtual attribute for completion status populated by SQL
  attribute :completion_status, :integer, default: 0
  
  # Add enum for completion status
  enum :completion_status, {
    not_started: 0,
    in_progress: 1,
    completed: 2
  }, prefix: true

  # Add virtual attributes for progress data
  attribute :next_activity_order, :integer, default: 0

  scope :with_progress_data, ->(user) {
    if user
      select(
        "lessons.*",
        "CASE 
          WHEN lesson_users.id IS NOT NULL THEN 2
          WHEN COALESCE(user_progress.completed_count, 0) > 0 THEN 1
          ELSE 0
         END as completion_status",
        "CASE 
          WHEN COALESCE(user_progress.completed_count, 0) = 0 THEN 0
          ELSE COALESCE(
            (SELECT MIN(activities.order) 
             FROM activities 
             WHERE activities.lesson_id = lessons.id 
               AND activities.order > user_progress.max_completed_order), 
            user_progress.max_completed_order + 1
          )
         END as next_activity_order"
      )
      .left_joins(:lesson_users)
      .joins(
        "LEFT JOIN (
          SELECT 
            activities.lesson_id,
            COUNT(activity_users.id) as completed_count,
            MAX(activities.order) as max_completed_order
          FROM activities
          LEFT JOIN activity_users ON activities.id = activity_users.activity_id 
            AND activity_users.user_id = #{user.id}
          WHERE activity_users.id IS NOT NULL
          GROUP BY activities.lesson_id
        ) user_progress ON lessons.id = user_progress.lesson_id"
      )
      .where("lesson_users.user_id = ? OR lesson_users.user_id IS NULL", user.id)
      .group("lessons.id, lesson_users.id, user_progress.completed_count, user_progress.max_completed_order")
    else
      select(
        "lessons.*",
        "0 as completion_status",
        "0 as next_activity_order"
      )
    end
  }

  def completed_by?(user)
    return false unless user
    lesson_users.exists?(user: user)
  end

  # Helper methods for status checking
  def not_started?
    completion_status == 'not_started' || completion_status == 0
  end

  def in_progress?
    completion_status == 'in_progress' || completion_status == 1
  end

  def completed?
    completion_status == 'completed' || completion_status == 2
  end
  
  def last_activity
    activities.order(:order).last
  end

  def create_activities
    intro = Activities::WatchVideoActivity.create!(lesson: self, order: 1)
    intro.phrases = medium.phrases.ordered_by_timestamp.between_durations(self.start_timestamp_seconds, self.endTimestamp_seconds)

    learn1 = Activities::MatchPhrasesActivity.create!(lesson: self, order: 2)
    learn1.phrases = medium.phrases.ordered_by_timestamp.between_durations(self.startTimestamp_seconds, self.endTimestamp_seconds).limit(5)    

    learn2 = Activities::SortPhrasesActivity.create!(lesson: self, order: 3)
    learn2.phrases = medium.phrases.ordered_by_timestamp.between_durations(self.startTimestamp_seconds, self.endTimestamp_seconds).limit(5)

    self.activities = [
      intro,
      learn1,
      learn2
    ]
  end
end
