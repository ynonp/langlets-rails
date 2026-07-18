class CourseTranslation < ApplicationRecord
  belongs_to :course, inverse_of: :course_translations
  belongs_to :language

  enum :status, { pending: 0, ready: 1, error: 2 }

  validates :name, presence: true
  validates :language_id, uniqueness: { scope: :course_id }
end
