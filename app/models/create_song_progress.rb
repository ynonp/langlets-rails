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
      broadcast_update
      
      translate unless data["phrases"][0]["text_l2"]
      broadcast_update
      
      add_token_translation unless data["phrases_with_token_translations"]
      broadcast_update
      
      add_lessons unless data["lessons"]
      broadcast_update
      
      add_similar_sound unless data["similar_sounds"]
      broadcast_update
    end
  end

  def broadcast_update
    reload
    course = Course.find_by(main_media_url: youtubeurl)
    
    CreateSongProgressChannel.broadcast_to(
      self,
      {
        progress_html: ApplicationController.render(
          partial: 'create_song_progresses/progress_steps',
          locals: { progress: self }
        ),
        content_html: ApplicationController.render(
          partial: 'create_song_progresses/content_display',
          locals: { progress: self, course: course }
        )
      }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast progress update: #{e.message}"
  end

  def ready?
    CourseBuilder::Base.new.collect_json_data(self)
    true
  rescue
    false
  end
end
