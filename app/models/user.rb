class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable, :omniauthable,
         omniauth_providers: [ :google_oauth2, :github, :apple ]

  # Ownership relationships
  has_many :courses, dependent: :destroy
  has_many :lessons, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_many :review_lesson_builds, dependent: :destroy

  # Courses on the user's Home — imported by them, or added from the Library.
  has_many :enrollments, dependent: :destroy
  has_many :enrolled_courses, through: :enrollments, source: :course

  # Videos the user has asked to turn into courses (the Queue screen).
  has_many :import_requests, dependent: :destroy

  has_many :channels, dependent: :destroy
  has_one :default_channel, -> { where(default: true) }, class_name: "Channel"
  has_many :channel_subscriptions, dependent: :destroy
  has_many :subscribed_channels, through: :channel_subscriptions, source: :channel
  has_many :channel_invitations, foreign_key: :invitee_id, dependent: :nullify
  has_many :sent_channel_invitations, class_name: "ChannelInvitation",
    foreign_key: :inviter_id, dependent: :destroy

  # Devices to push "your course is ready" to.
  has_many :device_tokens, dependent: :destroy

  # The user's own playlists. System playlists (user_id nil) are not included.
  has_many :playlists, dependent: :destroy

  # Progress tracking relationships
  has_many :lesson_users, dependent: :destroy
  has_many :completed_lessons, through: :lesson_users, source: :lesson

  has_many :activity_users, dependent: :destroy
  has_many :completed_activities, through: :activity_users, source: :activity

  # Activity logging relationship
  has_many :activity_logs, dependent: :destroy

  # XP / streak counters. Required for destroy: user_game_stats has a foreign
  # key to users with no ON DELETE rule, so without this the delete raises
  # ActiveRecord::InvalidForeignKey for any user who has earned XP.
  has_many :user_game_stats, dependent: :destroy

  # OAuth tokens issued to AI agents and the CLI (see settings/connections).
  # Destroyed with the account so a deleted user's tokens can't keep calling /mcp.
  has_many :oauth_access_grants,
           class_name: "Doorkeeper::AccessGrant",
           foreign_key: :resource_owner_id,
           dependent: :destroy
  has_many :oauth_access_tokens,
           class_name: "Doorkeeper::AccessToken",
           foreign_key: :resource_owner_id,
           dependent: :destroy

  # Saved L1 spans, pinned to the L2 language active when each was saved.
  has_many :phrase_token_users, dependent: :destroy
  has_many :saved_phrase_tokens, through: :phrase_token_users, source: :phrase_token

  # Credits meter video imports. users.credit_balance is the authority; the ledger
  # is the append-only audit behind it. Always move credits via Credits::Ledger.
  #
  # delete_all, not destroy: CreditLedgerEntry blocks destroy to stay append-only,
  # so `dependent: :destroy` would raise ReadOnlyRecord and make deleting an
  # account impossible. Erasing the account erases its ledger with it.
  has_many :credit_ledger_entries, dependent: :delete_all

  # What every new account starts with. Additional credits can be purchased
  # through the PayPal Payments Standard flow.
  SIGNUP_CREDITS = 3

  # after_create rather than after_create_commit so the user row, the balance and
  # the ledger entry all commit atomically — no window where an account exists
  # with no credits and no entry explaining why.
  after_create :grant_signup_credits
  after_create :provision_default_channel!

  def provision_default_channel!
    existing = default_channel
    return existing if existing

    channel = channels.create_or_find_by!(default: true) do |channel|
      channel.name = "My Channel"
      channel.slug = "channel-#{id}"
      channel.visibility = :private
    end
    association(:default_channel).reset
    channel
  rescue ActiveRecord::RecordNotUnique
    association(:default_channel).reset
    default_channel
  end

  def self.from_omniauth(auth)
    user = where(email: auth.info.email).first_or_initialize do |new_user|
      new_user.email = auth.info.email
      new_user.password = Devise.friendly_token[0, 20]
      # new_user.name = auth.info.name # if you have a name field
      new_user.provider = auth.provider
      new_user.uid = auth.uid
      new_user.confirmed_at = Time.current
    end

    # Update provider and uid for existing users logging in with different OAuth provider
    if user.persisted? && (user.provider != auth.provider || user.uid != auth.uid)
      user.update(provider: auth.provider, uid: auth.uid)
    end

    # Save if new record
    user.save if user.new_record?

    user
  end

  # Supported UI color themes. Stored under preferences["theme"].
  VALID_THEMES = %w[light dark].freeze
  DEFAULT_THEME = "dark".freeze

  # The learning language selected in the iOS app. The native shell clears its
  # local copy at sign-out, then receives this account-specific value again
  # after authentication.
  def ios_lang
    (preferences || {})["ios_lang"]
  end

  def ios_lang=(value)
    self.preferences = (preferences || {}).merge("ios_lang" => value)
  end

  # The user's chosen color theme, falling back to the default when unset or invalid.
  def theme
    stored = (preferences || {})["theme"]
    VALID_THEMES.include?(stored) ? stored : DEFAULT_THEME
  end

  # Persist a new color theme into the preferences JSON blob.
  def theme=(value)
    value = DEFAULT_THEME unless VALID_THEMES.include?(value)
    self.preferences = (preferences || {}).merge("theme" => value)
  end

  # Watch-video activity toggles, stored under preferences["watch_video"].
  # "translation" is a 2-state L1/L2 language toggle for the lyrics: false (the
  # default) shows L1, true shows L2.
  WATCH_VIDEO_PREF_KEYS = %w[translation karaoke].freeze
  WATCH_VIDEO_DEFAULTS = { "translation" => false, "karaoke" => true }.freeze

  # The user's watch-video toggle choices, merged over the defaults so missing
  # keys fall back to "on".
  def watch_video_preferences
    stored = (preferences || {})["watch_video"]
    WATCH_VIDEO_DEFAULTS.merge(stored.is_a?(Hash) ? stored.slice(*WATCH_VIDEO_PREF_KEYS) : {})
  end

  # Merge a partial set of watch-video toggle values into the preferences JSON.
  # Unknown keys are ignored and values are coerced to booleans.
  def watch_video_preferences=(values)
    cleaned = (values || {}).stringify_keys.slice(*WATCH_VIDEO_PREF_KEYS)
      .transform_values { |v| ActiveModel::Type::Boolean.new.cast(v) }
    merged = watch_video_preferences.merge(cleaned)
    self.preferences = (preferences || {}).merge("watch_video" => merged)
  end

  def admin?
    self.email == "ynon@hey.com"
  end

  # True when the user can afford to import a video.
  def credits?
    credit_balance.positive?
  end

  def recommended_for_me
    Course.none
  end

  def languages_with_saved_words
    Language.joins(phrases_as_l1: { phrase_tokens: :phrase_token_users })
      .where(phrase_token_users: { user_id: id })
      .distinct
  end

  def saved_phrase_tokens_for_language(language_code)
    language = Language.find_by(iso_name: language_code)
    return saved_phrase_tokens.none unless language

    saved_phrase_tokens
      .joins(phrase: :l1)
      .where(languages: { id: language.id })
  end

  def daily_vocab_review_available?(language_code)
    language = Language.find_by(iso_name: language_code)
    return false unless language
    return false unless phrase_token_users.joins(phrase_token: :phrase)
      .where(phrases: { l1_id: language.id }).exists?

    !lesson_users.joins(:lesson).where(
      lessons: { review_language_id: language.id },
      created_at: Time.zone.now.all_day
    ).exists?
  end

  def daily_vocab_review_language(preferred_code = nil)
    candidates = languages_with_saved_words.order(:iso_name)
    if preferred_code.present?
      preferred = candidates.find_by(iso_name: preferred_code)
      return preferred if preferred && daily_vocab_review_available?(preferred.iso_name)
    end

    candidates.detect { |language| daily_vocab_review_available?(language.iso_name) }
  end

  def sync_local_xp(local_xp_data)
    return unless local_xp_data.is_a?(Hash) && local_xp_data["dailyXp"].present?

    daily_xp = local_xp_data["dailyXp"].to_i

    # Only sync if the local XP is from today
    local_date = local_xp_data["date"]
    if local_date == Time.zone.now.to_date.to_s || local_date == Time.zone.now.to_date.strftime("%a %b %d %Y")
      ActivityLog.log_activity_completion(
        user: self,
        active_time: 0, # No time tracking for synced XP
        xp_gained: daily_xp
      )
    end
  end

  private

  # Keyed on the user id so a replay — or the backfill rake task — can never
  # double-grant.
  def grant_signup_credits
    Credits::Ledger.grant!(
      user: self,
      amount: SIGNUP_CREDITS,
      reason: :signup_grant,
      idempotency_key: "signup:#{id}"
    )

    # The ledger moves the balance with an UPDATE (it has to — that's what makes
    # spending safe under concurrency), which leaves this instance's copy at the
    # column default. Refresh it so `User.create!(...).credit_balance` isn't a
    # surprising 0. Safe here: the row is already inserted, and nothing else on
    # the instance is unsaved.
    reload
  end
end
