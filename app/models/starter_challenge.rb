class StarterChallenge < ApplicationRecord
  belongs_to :user
  has_many :starter_challenge_languages, dependent: :destroy
  has_many :languages, through: :starter_challenge_languages
  has_many :daily_challenges, dependent: :destroy
  has_many :daily_practice_reminders, dependent: :destroy

  validates :started_at, :first_challenge_on, :next_practice_at, presence: true
  validates :reminder_minute, inclusion: { in: 0..1439 }
  validate :supported_reminder_timezone
  validates :user_id, uniqueness: true
  validates :languages, presence: true

  # Serialize enrollment with account changes; repeated submissions never restart it.
  def self.parse_reminder!(time:, timezone:)
    match = /\A([01]\d|2[0-3]):([0-5]\d)\z/.match(time.to_s)
    zone = ActiveSupport::TimeZone[timezone]
    raise ArgumentError, "Choose a valid reminder time and timezone" unless match && zone
    [ match[1].to_i * 60 + match[2].to_i, zone.tzinfo.identifier ]
  end

  def reminder_time = format("%02d:%02d", reminder_minute / 60, reminder_minute % 60)
  def time_zone = ActiveSupport::TimeZone[reminder_timezone]
  def local_today = Time.zone.now.in_time_zone(time_zone).to_date

  def local_time_on(date)
    time_zone.local(date.year, date.month, date.day, reminder_minute / 60, reminder_minute % 60)
  end

  def active_day = (local_today - first_challenge_on).to_i + 1
  def practice_started? = active_day > 5
  def pending_quest = daily_challenges.find_by(day: [active_day, 1].max)
  def current_quest
    return if practice_started?
    quest = pending_quest
    quest if quest&.unlocked?
  end

  def practice_language
    chosen = languages.order(:id).to_a
    available = user.languages_with_saved_words.where(id: chosen.map(&:id)).pluck(:id)
    candidates = chosen.select { |language| available.include?(language.id) }
    candidates = chosen if candidates.empty?
    candidates[(local_today - first_challenge_on - 5).to_i % candidates.size]
  end

  def self.enroll!(user:, language_ids:, delivery:, reminder_time: "09:00", reminder_timezone: "UTC")
    ids = Array(language_ids).reject(&:blank?).map(&:to_s).uniq
    languages = Language.where(id: ids).to_a
    if languages.empty? || languages.map { |language| language.id.to_s }.sort != ids.sort
      raise ArgumentError, 'Choose at least one supported language'
    end

    minute, timezone = parse_reminder!(time: reminder_time, timezone: reminder_timezone)

    user.with_lock do
      user.update!(notification_delivery: delivery)
      challenge = find_by(user_id: user.id)
      if challenge
        next_date = [challenge.first_challenge_on + 5, Time.zone.now.in_time_zone(timezone).to_date].max
        next_date += 1 if challenge.daily_practice_reminders.exists?(local_date: next_date)
        next_time = ActiveSupport::TimeZone[timezone].local(next_date.year, next_date.month, next_date.day, minute / 60, minute % 60)
        challenge.update!(languages: languages, reminder_minute: minute, reminder_timezone: timezone,
          next_practice_at: next_time)
        challenge.daily_challenges.where(notification_id: nil, skipped_at: nil).find_each do |quest|
          quest.update!(available_at: challenge.local_time_on(challenge.first_challenge_on + quest.day - 1))
        end
      else
        started = Time.zone.now
        first_day = started.in_time_zone(timezone).to_date + 1
        challenge = create!(user: user, languages: languages, started_at: started,
          first_challenge_on: first_day, reminder_minute: minute, reminder_timezone: timezone,
          next_practice_at: ActiveSupport::TimeZone[timezone].local((first_day + 5).year, (first_day + 5).month,
            (first_day + 5).day, minute / 60, minute % 60))
        (1..5).each do |day|
          challenge.daily_challenges.create!(day: day, available_at: challenge.local_time_on(first_day + day - 1))
        end
      end
      challenge
    end
  end
  private

  def supported_reminder_timezone
    errors.add(:reminder_timezone, :invalid) unless ActiveSupport::TimeZone[reminder_timezone]
  end
end
