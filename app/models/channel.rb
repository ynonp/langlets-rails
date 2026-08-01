class Channel < ApplicationRecord
  class UnauthorizedTransition < StandardError; end
  class NotShared < StandardError; end

  belongs_to :user

  has_many :channel_items, dependent: :destroy
  has_many :courses, through: :channel_items
  has_many :channel_subscriptions, dependent: :destroy
  has_many :subscribers, through: :channel_subscriptions, source: :user
  has_many :channel_invitations, dependent: :destroy

  enum :visibility, { private: 0, shared: 1, public: 2 }, prefix: true

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
  validates :default, uniqueness: { scope: :user_id }, if: :default?

  # Which Channels this user may read.
  #
  # Access is a **union of independent grants**, one per way of getting it, each
  # returning the rows of its own kind. A new kind of Channel therefore adds a
  # grant of its own rather than a clause inside somebody else's WHERE — which is
  # how ProChannel expresses "readable only while the subscription is live"
  # without this scope knowing that subscriptions exist.
  #
  # Every grant is wrapped as `Channel.where(id: …)` before being OR-ed, because
  # `or` requires structurally compatible relations and `ProChannel.where(…)` is
  # not compatible with `Channel.where(…)` on its own.
  scope :visible_to, ->(user) {
    return none unless user
    return all if user.admin?

    grants(user)
      .map { |grant| where(id: grant.select(:id)) }
      .reduce { |readable, grant| readable.or(grant) }
  }

  def self.grants(user)
    [ public_grant, owned_grant(user), subscribed_grant(user), ProChannel.owned_grant(user) ].compact
  end

  def self.public_grant
    where(visibility: visibilities[:public])
  end

  # An ordinary Channel is readable by its owner forever. `type: nil` matters:
  # a base-class query sees subclass rows, so without it this would hand every
  # subscriber their Pro library back the moment they stopped paying for it.
  def self.owned_grant(user)
    where(type: nil, user_id: user.id)
  end

  def self.subscribed_grant(user)
    where(id: ChannelSubscription.where(user_id: user.id).select(:channel_id))
  end

  # Put a course in this channel — and take payment for it.
  #
  # Publishing is where a course becomes somebody's, so it is where the credit
  # moves. `ProChannel` overrides `charge_for!` to nothing; that override *is*
  # Langlets Pro. Everything else about pricing follows from those two facts:
  #
  #   publishing into a default Channel costs one credit
  #   publishing into a Pro library costs nothing
  #
  # Deliberately here rather than in Imports::Create. There used to be four
  # import outcomes each deciding its own price, so "somebody already built
  # this", "somebody is building it right now" and "nobody has built it" were
  # free, free and one credit for the same end state: a course in the user's
  # channel. Charging at the publication means who executed the pipeline, and
  # whether it ran a minute ago or a year ago, cannot change the price — there is
  # one thing being sold and one place it is sold.
  #
  # Idempotent in both stores. A course already here re-publishes for free, and
  # the ledger key is the (channel, course) pair rather than the import, so a
  # retried job, a second settlement, and deleting a course and importing it
  # again all buy it exactly once.
  #
  # Raises Credits::InsufficientCredits, which rolls the publication back with
  # it: a course the owner could not pay for does not appear in their channel.
  def publish!(course, published_at: Time.current)
    transaction do
      item = channel_items.create_or_find_by!(course:) do |channel_item|
        channel_item.published_at = published_at
      end

      charge_for!(course) if item.previously_new_record?

      item
    end
  end

  def <<(course)
    publish!(course)
    self
  end

  def unpublish!(course)
    channel_items.where(course: course).destroy_all
  end

  def readable_by?(actor)
    return false unless actor
    return true if actor.admin? || actor.id == user_id || visibility_public?
    visibility_shared? && channel_subscriptions.exists?(user_id: actor.id)
  end

  def discoverable_by?(actor)
    return true if readable_by?(actor)
    return false unless actor && visibility_shared?

    channel_invitations.pending.valid_now.where(
      "invitee_id = :id OR email = :email", id: actor.id, email: self.class.normalize_email(actor.email)
    ).exists?
  end

  def change_visibility!(new_visibility, actor:)
    target = new_visibility.to_s
    raise ArgumentError, "invalid visibility" unless self.class.visibilities.key?(target)
    raise UnauthorizedTransition unless actor&.admin? || actor&.id == user_id
    raise UnauthorizedTransition if !actor.admin? && (visibility_public? || target == "public")

    transaction do
      lock!
      if target == "private" && !visibility_private?
        channel_invitations.pending.update_all(status: ChannelInvitation.statuses[:revoked], updated_at: Time.zone.now)
        channel_subscriptions.delete_all
      end
      update!(visibility: target)
    end
  end

  def invite!(email:, inviter:)
    raise UnauthorizedTransition unless inviter&.admin? || inviter&.id == user_id
    raise NotShared unless visibility_shared?

    normalized = self.class.normalize_email(email)
    raise ActiveRecord::RecordInvalid, ChannelInvitation.new unless normalized.match?(URI::MailTo::EMAIL_REGEXP)
    existing = channel_invitations.pending.find_by(email: normalized)
    return existing if existing

    raw_token = SecureRandom.urlsafe_base64(32)
    invitation = channel_invitations.create!(
      inviter: inviter,
      invitee: User.find_by("LOWER(email) = ?", normalized),
      email: normalized,
      token_digest: ChannelInvitation.digest(raw_token),
      expires_at: ChannelInvitation::EXPIRY.from_now
    )
    ChannelInvitationMailer.with(invitation: invitation, token: raw_token).invite.deliver_later
    invitation
  rescue ActiveRecord::RecordNotUnique
    channel_invitations.pending.find_by!(email: normalized)
  end

  def self.normalize_email(email)
    email.to_s.strip.downcase
  end

  private

  # The price of one publication, charged to whoever owns the channel it lands
  # in. Overridden — to nothing — by ProChannel.
  def charge_for!(course)
    Credits::Ledger.spend!(
      user: user,
      amount: Imports::Pricing::CREDIT_COST,
      subject: course,
      idempotency_key: "publish:#{id}:#{course.id}"
    )
  end
end
