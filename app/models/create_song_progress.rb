class CreateSongProgress < ApplicationRecord
  validates :youtubeurl, presence: true
  validates :clip_language, presence: true
  validates :translation_language, presence: true

  include CreateSong::ExtractLyrics

  enum :step, {
    extract_lyrics: 0,
  }

end
