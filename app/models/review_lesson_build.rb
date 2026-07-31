class ReviewLessonBuild < ApplicationRecord
  belongs_to :user
  belongs_to :language, optional: true
  belongs_to :lesson, optional: true

  enum :status, {
    pending: 0,
    ready: 1,
    failed: 2
  }

  before_validation :assign_request_id, on: :create

  validates :request_id, presence: true, uniqueness: true
  validates :lesson, presence: true, if: :ready?

  private

  def assign_request_id
    self.request_id ||= SecureRandom.uuid
  end
end
