class CreateSongProgress < ApplicationRecord
  # Raised when a record or export file still uses the pre-multilanguage data
  # format (see CreateSongProgress::DataFormat).
  class LegacyFormatError < StandardError; end

  validates :youtubeurl, presence: true
  validates :clip_language, presence: true

  include CreateSong::ProgressReporting

  # This row is shared by every user importing the same video + language pair, so
  # one pipeline legitimately backs several people's queue cards — hence
  # update_all across all of them rather than a single request.
  #
  # Pushed forward on save rather than computed when the Queue asks, because
  # `data` is a multi-megabyte jsonb blob and the Queue polls. Here it's already
  # in memory, so the percent is free.
  after_save :sync_import_requests_progress

  # The AI steps that used to live here (extract_lyrics, add_lessons,
  # rate_lessons, add_similar_sound, translate, add_token_translation) now run
  # in the Deno pipeline and reach this record through
  # PipelineCallbacksController. Trigger a run with CreateSongPipelineHttp;
  # this class is the store and the guard predicates, not the worker.

  def translation_complete?(language)
    language = resolve_translation_language(language)
    language && data.dig("translations", language.iso_name, "phrases", 0, "text").present?
  end

  def translation_payload(language)
    language = resolve_translation_language(language)
    data.dig("translations", language&.iso_name)
  end

  def data_format_version = DataFormat.version(data)

  def current_data_format? = DataFormat.current?(data)

  def assert_current_data_format!
    return if current_data_format?

    raise LegacyFormatError,
          "CreateSongProgress #{id || youtubeurl} data is in the legacy single-language format; " \
          "convert it with rake create_song_progress:convert_records (or convert_files for JSON exports)"
  end

  # Upgrade a legacy blob in place: the inline text_l2 / word translations are
  # the translation_language's, so move them into that language's payload.
  def upgrade_data_format!
    return self if current_data_format?

    language = resolve_translation_language(translation_language)
    raise LegacyFormatError, "cannot upgrade #{youtubeurl}: unknown translation language #{translation_language.inspect}" unless language

    DataFormat.pack_translation(data, language)
    save!
    self
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

  def resolve_translation_language(value)
    return value if value.is_a?(Language)

    Language.find_by(english_name: value) || Language.find_by(iso_name: value)
  end

  # Both columns are pushed forward here for the same reason: `data` is in memory
  # at this point, so deriving them is free, whereas the Queue would have to load
  # the whole blob per card on every 3-second poll to work them out itself.
  def sync_import_requests_progress
    ImportRequest.where(create_song_progress_id: id, status: :importing)
                 .update_all(progress_percent: progress_percent,
                             pipeline_step: current_step_label)
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
