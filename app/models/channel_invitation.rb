class ChannelInvitation < ApplicationRecord
  EXPIRY = 7.days

  belongs_to :channel
  belongs_to :inviter, class_name: "User"
  belongs_to :invitee, class_name: "User", optional: true

  enum :status, { pending: 0, accepted: 1, declined: 2, revoked: 3, expired: 4 }

  validates :email, :token_digest, :expires_at, presence: true
  validates :token_digest, uniqueness: true

  scope :valid_now, -> { where("expires_at > ?", Time.zone.now) }

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def self.find_by_token(token)
    find_by(token_digest: digest(token))
  end

  def accept!(actor)
    transition_for!(actor, :accepted) do
      ChannelSubscription.create_or_find_by!(channel: channel, user: actor)
      self.accepted_at = Time.zone.now
    end
  end

  def decline!(actor)
    transition_for!(actor, :declined)
  end

  def revoke!(actor)
    raise Channel::UnauthorizedTransition unless actor&.admin? || actor&.id == channel.user_id
    update!(status: :revoked) if pending?
  end

  def resend!(actor)
    raise Channel::UnauthorizedTransition unless actor&.admin? || actor&.id == channel.user_id
    raise ActiveRecord::RecordInvalid, self unless pending? && channel.visibility_shared?

    raw_token = SecureRandom.urlsafe_base64(32)
    update!(token_digest: self.class.digest(raw_token), expires_at: EXPIRY.from_now)
    ChannelInvitationMailer.with(invitation: self, token: raw_token).invite.deliver_later
  end

  private

  def transition_for!(actor, target)
    outcome = transaction do
      lock!
      if accepted? && target == :accepted && actor &&
          Channel.normalize_email(actor.email) == email &&
          channel.channel_subscriptions.exists?(user: actor)
        next :already_accepted
      end
      raise ActiveRecord::RecordNotFound unless pending?
      if expires_at <= Time.zone.now
        update!(status: :expired)
        next :expired
      end
      raise ActiveRecord::RecordNotFound unless actor && Channel.normalize_email(actor.email) == email

      yield if block_given?
      update!(status: target)
      :transitioned
    end
    raise ActiveRecord::RecordNotFound if outcome == :expired
    self
  end
end
