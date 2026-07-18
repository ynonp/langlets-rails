class LessonTranslation < ApplicationRecord
  belongs_to :lesson, inverse_of: :lesson_translations
  belongs_to :language

  validates :name, presence: true
  validates :language_id, uniqueness: { scope: :lesson_id }
end
