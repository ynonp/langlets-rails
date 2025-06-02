class CreateSongProgress < ApplicationRecord
  enum :step, {
    create_phrases: 0,
    create_token_translations: 1,
    create_lessons: 2,
    create_lesson_activities: 3
  }
end
