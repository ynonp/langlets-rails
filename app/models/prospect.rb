class Prospect < ApplicationRecord
  belongs_to :course, optional: true
  belongs_to :lesson, optional: true
  belongs_to :user, optional: true

  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :locale, inclusion: { in: %w[en he] }

  generates_token_for :setup, expires_in: 7.days do
    activated_at
  end

  # The email link proves ownership. Existing accounts keep their credentials;
  # only a new account needs a password. Both paths redeem the offer once.
  def activate!(password: nil, password_confirmation: nil)
    with_lock do
      raise ActiveRecord::RecordNotFound if activated_at?
      account = User.find_by(email: email)
      if account.nil?
        account = User.new(email: email, password: password, password_confirmation: password_confirmation)
        account.skip_confirmation!
        account.native_language = locale
        account.save!
      end
      account.with_lock do
        account.pro! unless account.reload.pro?
      end
      update!(user: account, activated_at: Time.zone.now)
      account
    end
  end
end
