class CreateSongProgress < ApplicationRecord
  validates :youtubeurl, presence: true
  validates :clip_language, presence: true
  validates :translation_language, presence: true

  include CreateSong::ExtractLyrics
  include CreateSong::AddTokenTranslations
  include CreateSong::AddLessons
  include CreateSong::AddSimilarSound
  include CreateSong::Translate

  attribute :model_params_youtube, default: {model: 'gemini-3.5-flash', provider: :gemini, assume_model_exists: true }
  attribute :model_params_quick, default: {model: 'gemini-3-flash-preview', provider: :gemini, assume_model_exists: true }
  attribute :model_params_smart, default: {model: 'gemini-3.1-pro', provider: :gemini, assume_model_exists: true }
  attribute :model_params_translate, default: {model: 'gemini-3-flash-preview', provider: :gemini, assume_model_exists: true }

  def use_local_ollama
    # self.model_params_youtube = {model: 'gemini-3-flash-preview:cloud', provider: :openai, assume_model_exists: true}
    self.model_params_quick = {model: 'deepseek-v4-flash:cloud', provider: :openai, assume_model_exists: true}
    self.model_params_smart = {model: 'deepseek-v4-pro:cloud', provider: :openai, assume_model_exists: true}
    self.model_params_translate = {model: 'qwen3.5:397b-cloud', provider: :openai, assume_model_exists: true}
  end

  def create_data
    span_name = "Create Song Progress #{youtubeurl} - #{clip_language} / #{translation_language}"
    LangfuseTracer.in_span(span_name, attributes: { }) do |span|
      extract_lyrics unless data["phrases"].present?
      translate unless data.dig("phrases", 0, "text_l2")
      add_token_translation unless data["phrases_with_token_translations"].present?
      add_lessons unless data["lessons"].present?
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
