# One row per device that has agreed to receive push.
#
# `token` is unique across all users, not per user — see the migration. Register
# with `DeviceToken.register!`, which handles the device-changed-hands case.
class DeviceToken < ApplicationRecord
  belongs_to :user

  enum :platform, { ios: 0 }

  ENVIRONMENTS = %w[production sandbox].freeze

  validates :token, presence: true, uniqueness: true
  validates :environment, inclusion: { in: ENVIRONMENTS }

  scope :active, -> { where(invalidated_at: nil) }

  # Upsert on the token, reassigning the user if the device has changed hands.
  # Re-registering also revives a token Apple previously rejected: iOS only hands
  # one out again when the install is genuinely able to receive push.
  def self.register!(user:, token:, environment: "production", app_version: nil)
    device = find_or_initialize_by(token: token)

    device.user = user
    device.environment = environment
    device.app_version = app_version
    device.last_seen_at = Time.zone.now
    device.invalidated_at = nil
    device.save!

    device
  end

  # Apple says this token is gone. Not destroyed: keeping it makes "I stopped
  # getting notifications" answerable, and re-registering revives it.
  def invalidate!
    update_columns(invalidated_at: Time.zone.now, updated_at: Time.zone.now)
  end

  def active?
    invalidated_at.nil?
  end

  def sandbox?
    environment == "sandbox"
  end
end
