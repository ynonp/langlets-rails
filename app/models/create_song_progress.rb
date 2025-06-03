class CreateSongProgress < ApplicationRecord
  enum :step, {
    create_phrases: 0,
    create_token_translations: 1,
    create_lessons: 2,
    create_listening_activities: 3,
    create_language_alignment_activities: 4,
    create_audio: 5,
    ready: 6,
  }
end
