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

  scope :visible_to, ->(user) {
    return none unless user
    return all if user.admin?

    where(visibility: visibilities[:public])
      .or(where(user_id: user.id))
      .or(where(id: ChannelSubscription.where(user_id: user.id).select(:channel_id)))
  }

  def publish!(course, published_at: Time.zone.now)
    channel_items.create_or_find_by!(course: course) do |item|
      item.published_at = published_at
    end
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
end
