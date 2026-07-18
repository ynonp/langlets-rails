class CreateSongProgress < ApplicationRecord
  # Raised when a record or export file still uses the pre-multilanguage data
  # format (see CreateSongProgress::DataFormat).
  class LegacyFormatError < StandardError; end

  validates :youtubeurl, presence: true
  validates :clip_language, presence: true

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
      add_lessons unless data["lessons"].present?
      rate_lessons unless lessons_rated?
      add_similar_sound unless similar_sounds_complete?
      add_translation(translation_language) if translation_language.present? && !translation_complete?(translation_language)
    end
  end

  # Run only the L2-dependent work for a target language. Neutral transcription,
  # timings, lesson segmentation, ratings, and similar sounds remain shared.
  def add_translation(language)
    previous = @target_translation_language
    language = resolve_translation_language(language)
    raise ArgumentError, "unknown translation language" unless language

    assert_current_data_format!
    # Stamp before translate writes inline text_l2: an interrupted run must
    # not leave a blob that shape-classifies as legacy on retry.
    data["format_version"] = DataFormat::VERSION

    @target_translation_language = language
    translate
    add_token_translation

    DataFormat.pack_translation(data, language)
    save!

    Course.where(create_song_progress_id: id).find_each do |course|
      CourseBuilder::BuildSong.new(self, course).add_translation(language) if course.lessons.exists?
    end
    language
  ensure
    @target_translation_language = previous
  end

  def translation_complete?(language)
    language = resolve_translation_language(language)
    language && data.dig("translations", language.iso_name, "phrases", 0, "text").present?
  end

  def translation_payload(language)
    language = resolve_translation_language(language)
    data.dig("translations", language&.iso_name)
  end

  def translation_language
    @target_translation_language&.english_name || super
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
