class EvaluationSignup < ApplicationRecord
  has_one :user
  belongs_to :admin_import_request, class_name: "ImportRequest"
  belongs_to :initial_course, class_name: "Course"
  belongs_to :course

  validates :video_url, :video_id, :provider, :title, :translation_language, presence: true
  validates :token, uniqueness: true

  scope :unconsumed, -> { where(consumed_at: nil) }
  scope :available, -> { unconsumed.where(created_at: 1.day.ago..) }

  def claim!(claiming_user)
    with_lock do
      raise ActiveRecord::RecordNotFound if consumed_at? || created_at < 1.day.ago
      claimed_user = User.find_by(evaluation_signup_id: id)
      raise ActiveRecord::RecordNotFound if claimed_user.present? && claimed_user != claiming_user

      previous_evaluation = claiming_user.evaluation_signup
      previous_evaluation.consume! if previous_evaluation && previous_evaluation != self
      claiming_user.update!(evaluation_signup: self)
      association(:user).reset
      update!(claimed_at: claimed_at || Time.zone.now)
      GuestImports::Claim.call(user: claiming_user, evaluation_signup: self)
    end
  end

  def consume!
    update!(consumed_at: Time.zone.now) if consumed_at.nil?
  end
end
