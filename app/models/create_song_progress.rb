class CreateSongProgress < ApplicationRecord
  # Raised when a record or export file still uses the pre-multilanguage data
  # format (see CreateSongProgress::DataFormat).
  class LegacyFormatError < StandardError; end

  validates :youtubeurl, presence: true

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

  # The pipeline has no "run finished" callback — it streams patches and stops.
  # So "is it done?" is a question about the blob, and these three predicates
  # are how every caller asks it.
  #
  # finalize_translation stamps the language payload's lessons snapshot, and it
  # runs only once *both* translation branches succeeded, which makes that one
  # key the whole language's completion signal (pipeline/src/steps/
  # finalizeTranslation.ts).
  def translation_finalized?(language)
    language = resolve_translation_language(language)
    language.present? && translation_payload(language).to_h["lessons"].present?
  end

  # The language-neutral half: all six steps done for *some* language. Cheap
  # (every predicate is a dig into data already in memory), which is why the
  # callback controller gates on this before asking the costlier questions.
  def pipeline_complete? = current_step.nil?

  # Everything a course needs in `language`: the neutral skeleton every step
  # feeds plus that language's finalized payload. The per-language half matters
  # — a record can be complete for Hebrew and still owe French.
  def complete_for?(language)
    pipeline_complete? && translation_finalized?(language)
  end

  # Failures the pipeline reported through the callback, newest last.
  def pipeline_errors = Array(data && data["errors"])

  # The pipeline stamps occurred_at to the second, while the timestamps we
  # compare it against carry sub-second precision. "An earlier run" means
  # minutes or hours ago, so a minute of slack costs nothing and keeps a
  # same-second error from reading as stale.
  ERROR_CLOCK_SKEW = 1.minute

  # The first reported failure that the run cannot recover from, ignoring
  # anything that landed before `since` (a resumed run skips steps it already
  # completed, so it never clears their stale errors). A complete blob
  # contradicts any leftover failure entry and is allowed to publish.
  def blocking_error(since: nil)
    return nil if pipeline_complete?

    pipeline_errors.find do |entry|
      next true if since.nil?

      occurred_at = parse_time(entry["occurred_at"])
      occurred_at.nil? || occurred_at >= since - ERROR_CLOCK_SKEW
    end
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
          "convert it with rake create_song_progress:convert_files"
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

  def parse_time(value)
    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

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
