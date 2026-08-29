class User < ApplicationRecord
  include UserImportFiltering

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable, :omniauthable,
         omniauth_providers: [ :google_oauth2, :github, :apple ]

  # Ownership relationships
  has_many :courses, dependent: :destroy
  has_many :lessons, dependent: :destroy
  has_many :activities, dependent: :destroy
  belongs_to :evaluation_signup, optional: true

  # Courses on the user's Home — imported by them, or added from the Library.
  has_many :enrollments, dependent: :destroy
  has_many :enrolled_courses, through: :enrollments, source: :course

  has_many :channels, dependent: :destroy
  # `type: nil` because a base-class query sees subclass rows: without it a
  # ProChannel could satisfy "the default channel" if one were ever mis-flagged.
  has_one :default_channel, -> { where(default: true, type: nil) }, class_name: "Channel"

  # The Pro library. Owned by this user like any other Channel — what makes it
  # different is that ProChannel only grants access while the subscription is
  # live. STI scopes the association to type = 'ProChannel' for free.
  has_one :pro_channel, class_name: "ProChannel", dependent: :destroy
  has_many :channel_subscriptions, dependent: :destroy
  has_many :subscribed_channels, through: :channel_subscriptions, source: :channel
  has_many :channel_invitations, foreign_key: :invitee_id, dependent: :nullify
  has_many :sent_channel_invitations, class_name: "ChannelInvitation",
    foreign_key: :inviter_id, dependent: :destroy

  # Devices to push "your course is ready" to.
  has_many :device_tokens, dependent: :destroy

  # Everything the app has told this user. The row is created before delivery is
  # attempted, so it is the complete history regardless of the delivery
  # preference below — see Notification.
  has_many :notifications, dependent: :delete_all

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

  # Langlets Pro. A user can accumulate several rows over time — a lapsed
  # subscription plus the one that replaced it — so entitlement is a query, not
  # a flag, and `Subscription.entitling` is its single definition.
  has_many :subscriptions, dependent: :destroy

  # What every new account starts with, and — since credits stopped being sold —
  # every credit an ordinary account will ever have. Past the allowance the way
  # forward is Langlets Pro, whose imports are not metered at all.
  SIGNUP_CREDITS = 3

  # after_create rather than after_create_commit so the user row, the balance and
  # the ledger entry all commit atomically — no window where an account exists
  # with no credits and no entry explaining why.
  after_create :grant_signup_credits
  after_create :provision_default_channel!

  def provision_default_channel!
    existing = default_channel
    return existing if existing

    channel = channels.create_or_find_by!(default: true, type: nil) do |channel|
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

  # One public Channel per user, provisioned lazily the first time they share
  # a course — mirrors provision_default_channel!. Its sole purpose is
  # publishing a course to a link anyone can open, so it is always :public
  # rather than following the default Channel's private visibility.
  def share_channel
    existing = channels.find_by(share: true, type: nil)
    return existing if existing

    channel = channels.create_or_find_by!(share: true, type: nil) do |channel|
      channel.name = "Shared by #{email}"
      channel.slug = "share-#{id}"
      channel.visibility = :public
    end
    channel
  rescue ActiveRecord::RecordNotUnique
    channels.find_by!(share: true, type: nil)
  end

  # Whether this user has this course on their share Channel. Deliberately
  # does not provision the Channel just to answer "no" for a user who has
  # never shared anything.
  def sharing?(course)
    channels.find_by(share: true, type: nil)&.channel_items&.exists?(course_id: course.id) || false
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

  # Which channels this account wants to be told about things over
  # (DeliverNotificationJob). Stored under preferences["notification_delivery"]
  # as the list of channels that are on — the channels are independent, so a
  # list says everything a "both" option used to, and one more thing besides:
  # the empty list, meaning the notification stays on /notifications and is
  # delivered nowhere. Both channels is the default, because that is what the
  # app did before the preference existed.
  #
  # This governs the notification subsystem only. Transactional mail that is not
  # a notification — Devise confirmations and password resets, Channel
  # invitations — is unaffected: those are answers to something the user just
  # did, and silently dropping them would break the flow that asked for them.
  NOTIFICATION_DELIVERIES = %w[email push].freeze
  DEFAULT_NOTIFICATION_DELIVERY = NOTIFICATION_DELIVERIES

  # Anything that isn't a list is a value this code never wrote, so it means
  # "unset" and gets the default — an empty list has to survive the round trip,
  # since it is the one preference a user can hold that looks like nothing.
  def notification_delivery
    stored = (preferences || {})["notification_delivery"]
    return DEFAULT_NOTIFICATION_DELIVERY.dup unless stored.is_a?(Array)

    sanitize_notification_delivery(stored)
  end

  # Intersected with the known channels rather than filtered, so the stored list
  # is always in one canonical order, deduped, and free of anything the delivery
  # job wouldn't recognise. Accepts a single channel as well as a list; the
  # blank entry the form's hidden field submits drops out on its own.
  def notification_delivery=(values)
    self.preferences = (preferences || {}).merge(
      "notification_delivery" => sanitize_notification_delivery(Array(values))
    )
  end

  def email_notifications? = notification_delivery.include?("email")
  def push_notifications? = notification_delivery.include?("push")

  # The platform account. It moderates everything.
  ADMIN_EMAIL = "ynon@hey.com".freeze

  def admin?
    self.email == ADMIN_EMAIL
  end

  # True when the user can afford to import a video.
  def credits?
    credit_balance.positive?
  end

  # Langlets Pro entitlement — unlimited imports, no credit spend.
  #
  # Memoised per instance because Home renders it and then the import path asks
  # again; call `reload` (or re-find the user) after a purchase, exactly as the
  # credit balance requires.
  def pro?
    return @pro if defined?(@pro)

    @pro = subscriptions.entitling.exists?
  end

  # The subscription behind `pro?`, for screens that name the plan.
  def pro_subscription
    subscriptions.entitling.order(expires_at: :desc).first
  end

  # Grants Langlets Pro by hand from the console — the only way an account
  # becomes Pro now that nothing is sold. Writes the same kind of row a real
  # Apple purchase would (a Subscription `subscriptions.entitling` sees), so
  # `pro?` and everything built on it (the Pro library, unmetered imports)
  # need no separate branch for a console grant. `product_id` deliberately
  # matches no entry in `Apple::SubscriptionPlans`, so `apple_plan` — and any
  # screen that reads it — correctly shows no purchase receipt.
  def pro!(expires_at: 100.years.from_now)
    subscription = subscriptions.create!(
      plan: :yearly,
      status: :active,
      product_id: "console_grant",
      original_transaction_id: "console_grant:#{id}:#{SecureRandom.uuid}",
      purchased_at: Time.zone.now,
      expires_at: expires_at
    )
    reload
    subscription
  end

  # How much of the signup allowance is gone — what the Pro upsell counts down.
  # Still clamped: the allowance is the only credit an account earns by itself,
  # but a console `admin_adjustment` or `promo_grant` can put more in, and
  # "you've used 7 of 3 free imports" is nonsense.
  def free_imports_used
    [ credit_ledger_entries.import_spend.count, SIGNUP_CREDITS ].min
  end

  # Where a newly imported Course is published.
  #
  # Free accounts publish to their own default Channel and keep that content
  # forever. Pro imports go to the Pro library instead, which is lent for as long
  # as the subscription runs — that difference *is* the subscription. Courses
  # imported before subscribing stay where they were: Pro adds a new home, it
  # does not move the old one.
  def publishing_channel
    pro? ? provision_pro_channel! : provision_default_channel!
  end

  # The Pro library, created on demand — on the first import made while
  # subscribed, so an account that subscribes and never imports carries no empty
  # channel. Mirrors provision_default_channel! down to the retry.
  def provision_pro_channel!
    existing = pro_channel
    return existing if existing

    channel = ProChannel.create_or_find_by!(user_id: id) do |new_channel|
      new_channel.name = ProChannel::NAME
      new_channel.slug = "pro-#{id}"
      new_channel.visibility = :private
    end
    association(:pro_channel).reset
    channel
  rescue ActiveRecord::RecordNotUnique
    association(:pro_channel).reset
    pro_channel
  end

  # Whether this course sits in a Channel this user publishes to, which is what
  # makes Delete meaningful: it removes their own contribution, never anyone
  # else's. Both homes count — a course imported while subscribed lives in the
  # Pro library, and Delete has to reach it after the subscription ends too.
  def owns_publication_of?(course)
    channel_ids = [ default_channel&.id, pro_channel&.id ].compact
    return false if channel_ids.empty?

    ChannelItem.where(channel_id: channel_ids, course_id: course.id).exists?
  end

  def reload(...)
    remove_instance_variable(:@pro) if defined?(@pro)
    super
  end

  def recommended_for_me
    Course.none
  end

  # Languages this user still practises words in. Paused words are deliberately
  # excluded: they stay listed in the Vocabulary tab but must not conjure a
  # daily review for a language the user has retired.
  def languages_with_saved_words
    Language.joins(phrases_as_l1: { phrase_tokens: :phrase_token_users })
      .where(phrase_token_users: { user_id: id, practicing: true })
      .distinct
  end

  def current_review_lesson(language_code)
    language = Language.find_by!(iso_name: language_code)

    with_lock do
      current_review_lesson_for(language) ||
        ReviewLessonBuilder.new(self, language_code: language.iso_name).build!
    end
  end

  def refresh_review_lesson!(language)
    with_lock do
      lessons.pending_review_lessons.where(review_language: language).update_all(
        review_build_status: Lesson.review_build_statuses[:expired],
        updated_at: Time.zone.now
      )
    end
    BuildReviewLessonJob.perform_later(id, language.id)
  end

  def saved_phrase_tokens_for_language(language_code)
    language = Language.find_by(iso_name: language_code)
    return saved_phrase_tokens.none unless language

    saved_phrase_tokens
      .joins(phrase: :l1)
      .where(languages: { id: language.id })
  end

  def current_review_lesson_for(language)
    lessons.review_lessons.where(review_language: language)
      .where(review_build_status: [ :started, :pending ])
      .order(Arel.sql("CASE review_build_status WHEN #{Lesson.review_build_statuses[:started]} THEN 0 ELSE 1 END"), created_at: :desc)
      .first
  end

  private :current_review_lesson_for

  def daily_vocab_review_available?(language_code)
    language = Language.find_by(iso_name: language_code)
    return false unless language
    return false unless phrase_token_users.practising.joins(phrase_token: :phrase)
      .where(phrases: { l1_id: language.id }).exists?

    !lesson_users.joins(:lesson).where(
      lessons: { review_language_id: language.id },
      created_at: Time.zone.now.all_day
    ).exists?
  end

  def daily_vocab_review_language(preferred_code = nil)
    candidates = languages_with_saved_words
      .distinct(false)
      .group("languages.id")
      .order(Arel.sql("MAX(phrase_token_users.updated_at) DESC, MAX(phrase_token_users.id) DESC"))
    if preferred_code.present?
      preferred = candidates.find_by(iso_name: preferred_code)
      return preferred if preferred && daily_vocab_review_available?(preferred.iso_name)
    end

    candidates.detect { |language| daily_vocab_review_available?(language.iso_name) }
  end

  def daily_vocab_review_lessons
    completed_language_ids = lesson_users.joins(:lesson)
      .where(lesson_users: { created_at: Time.zone.now.all_day })
      .where.not(lessons: { review_language_id: nil })
      .distinct
      .pluck("lessons.review_language_id")

    active_reviews = lessons.review_lessons
      .where(review_build_status: [ :started, :pending ])
      .where.not(review_language_id: completed_language_ids)
      .includes(:review_language)
      .order(created_at: :desc)
      .to_a

    active_reviews
      .group_by(&:review_language_id)
      .values
      .map { |reviews| reviews.find(&:review_started?) || reviews.first }
      .sort_by { |lesson| lesson.review_language.english_name }
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

  def sanitize_notification_delivery(values)
    NOTIFICATION_DELIVERIES & values.map(&:to_s)
  end

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
