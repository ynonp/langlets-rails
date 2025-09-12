class CreateSongProgress < ApplicationRecord
  validates :youtubeurl, presence: true
  validates :clip_language, presence: true
  validates :translation_language, presence: true

  include CreateSong::ExtractLyrics
  include CreateSong::AddTokenTranslations
  include CreateSong::AddLessons
  include CreateSong::AddSimilarSound
  include CreateSong::Translate

  def create_data
    span_name = "Create Song Progress #{youtubeurl} - #{clip_language} / #{translation_language}"
    LangfuseTracer.in_span(span_name, attributes: { }) do |span|
      extract_lyrics unless data["phrases"]
      translate unless data["phrases"][0]["text_l2"]
      add_token_translation unless data["phrases_with_token_translations"]
      add_lessons unless data["lessons"]
      add_similar_sound unless data["similar_sounds"]
    end
  end

  def ready?
    CourseBuilder::Base.new.collect_json_data(self)
    true
  rescue
    false
  end
end
