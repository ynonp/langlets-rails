class CreateSongProgress < ApplicationRecord
  validates :youtubeurl, presence: true
  validates :clip_language, presence: true
  validates :translation_language, presence: true

  include CreateSong::ExtractLyrics
  include CreateSong::AddTokenTranslations
  include CreateSong::AddLessons
  include CreateSong::RateLessons
  include CreateSong::AddSimilarSound
  include CreateSong::Translate
  include CreateSong::ProgressReporting

  # This row is shared by every user importing the same video + language pair, so
  # one pipeline legitimately backs several people's queue cards — hence
  # update_all across all of them rather than a single request.
  #
  # Pushed forward on save rather than computed when the Queue asks, because
  # `data` is a multi-megabyte jsonb blob and the Queue polls. Here it's already
  # in memory, so the percent is free.
  after_save :sync_import_requests_progress

  def create_data
    span_name = "Create Song Progress #{youtubeurl} - #{clip_language} / #{translation_language}"
    LangfuseTracer.in_span(span_name, attributes: { }) do |span|
      # Run extract_lyrics when we have no phrases yet, or when a previous run
      # started the step but never finished it (the in-progress flag is still
      # set). Relying on phrases alone isn't enough: extract_lyrics now saves
      # phrases turn-by-turn, so a partially-transcribed, failed run also leaves
      # phrases present -- the flag is what tells "done" apart from "interrupted".
      extract_lyrics if data["phrases"].blank? || data["extract_lyrics_in_progress"]
      translate unless data.dig("phrases", 0, "text_l2")
      add_token_translation unless data.dig("phrases", 0, "words", 0, "translation").present?
      add_lessons unless data["lessons"].present?
      rate_lessons unless lessons_rated?
      add_similar_sound unless similar_sounds_complete?
    end
  end

  def ready?
    CourseBuilder::Base.new.collect_json_data(self)
    true
  rescue
    false
  end

  def export(output_file)
    export_data = {
      youtubeurl: youtubeurl,
      clip_language: clip_language,
      translation_language: translation_language,
      step: step,
      data: data,
      created_at: created_at,
      updated_at: updated_at,
      exported_at: Time.current.iso8601
    }

    File.write(output_file, JSON.pretty_generate(export_data))
  end

  def save_phrases_to_srt(output_file)
    phrases = data["phrases"]
    return false unless phrases.present?

    srt_content = phrases.each_with_index.map do |phrase, index|
      seq = index + 1
      start_ts = srt_timestamp(phrase["timestamp"])
      end_ts   = srt_timestamp(phrase["timestamp_end"])
      text     = phrase["text_l1"]

      "#{seq}\n#{start_ts} --> #{end_ts}\n#{text}\n"
    end.join("\n")

    File.write(output_file, srt_content, encoding: "UTF-8")
    true
  end

  private

  def sync_import_requests_progress
    ImportRequest.where(create_song_progress_id: id, status: :importing)
                 .update_all(progress_percent: progress_percent)
  end

  def srt_timestamp(ts)
    parts = ts.split(":")
    minutes = parts[0].to_i
    seconds = parts[1].to_f
    total_seconds = (minutes * 60) + seconds

    hours   = total_seconds.to_i / 3600
    mins    = (total_seconds.to_i % 3600) / 60
    secs    = total_seconds % 60

    format("%02d:%02d:%06.3f", hours, mins, secs).sub(".", ",")
  end
end
