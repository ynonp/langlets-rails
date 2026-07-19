class Lesson < ApplicationRecord
  belongs_to :user
  belongs_to :medium, optional: true
  belongs_to :course, optional: true
  has_many :activities, dependent: :destroy
  has_many :activity_logs, dependent: :nullify
  has_many :lesson_translations, dependent: :destroy, inverse_of: :lesson
  has_one :localized_translation,
          -> { where(language_id: Current.translation_language_id) },
          class_name: "LessonTranslation"
  has_timestamp [ :start_timestamp, :end_timestamp ]
  include FriendlyName

  validates :slug, uniqueness: { scope: :course_id }, allow_blank: true

  def localized_name = localized_translation&.name || name

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



  scope :with_progress_data, ->(user) {
    if user
      select(
        "lessons.*",
        "CASE 
          WHEN lesson_users.id IS NOT NULL THEN 2
          WHEN COALESCE(user_progress.completed_count, 0) > 0 THEN 1
          ELSE 0
         END as completion_status"
      )
      .left_joins(:lesson_users)
      .joins(
        "LEFT JOIN (
          SELECT 
            activities.lesson_id,
            COUNT(activity_users.id) as completed_count
          FROM activities
          LEFT JOIN activity_users ON activities.id = activity_users.activity_id 
            AND activity_users.user_id = #{user.id}
          WHERE activity_users.id IS NOT NULL
          GROUP BY activities.lesson_id
        ) user_progress ON lessons.id = user_progress.lesson_id"
      )
      .where("lesson_users.user_id = ? OR lesson_users.user_id IS NULL", user.id)
      .group("lessons.id, lesson_users.id, user_progress.completed_count")
    else
      select(
        "lessons.*",
        "0 as completion_status"
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
