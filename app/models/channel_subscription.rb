class ChannelSubscription < ApplicationRecord
  belongs_to :channel
  belongs_to :user

  validate :subscriber_is_not_owner

  private

  def subscriber_is_not_owner
    errors.add(:user, :invalid) if channel&.user_id == user_id
  end
end
