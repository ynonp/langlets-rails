class CreateSongProgress < ApplicationRecord
  validates :youtubeurl, presence: true
  validates :clip_language, presence: true
  validates :translation_language, presence: true

  include CreateSong::ExtractLyrics
  include CreateSong::AddTokenTranslations
  include CreateSong::AddLessons
  include CreateSong::AddSimilarSound
  include CreateSong::AddHebrewScript

  def create_data
    extract_lyrics
    add_token_translation
    add_lessons
    add_similar_sound
  end

  def ready?
    CourseBuilder::Base.new.collect_json_data(self)
    true
  rescue
    false
  end
end
