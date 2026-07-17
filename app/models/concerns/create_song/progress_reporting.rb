module CreateSong
  # Turns the pipeline's state into a single 0-100 number for the Queue screen.
  #
  # Derived from `data` rather than from the `step` column: create_data already
  # guards each of its six steps on the contents of `data`, so a data-derived
  # percent stays honest across resumes and partial runs. A parallel counter would
  # be a second source of truth, and it would drift.
  module ProgressReporting
    extend ActiveSupport::Concern

    # Roughly proportional to wall-clock time. extract_lyrics dominates: it's a
    # multi-turn transcription of the whole video.
    STEP_WEIGHTS = {
      extract_lyrics: 45,
      translate: 12,
      add_token_translation: 20,
      add_lessons: 8,
      rate_lessons: 5,
      add_similar_sound: 10
    }.freeze

    # Never report 0 (reads as "nothing is happening") and never report 100 until
    # the course is actually published — that's the job's call, not ours.
    MIN_REPORTED = 5
    MAX_REPORTED = 97

    def progress_percent
      earned = STEP_WEIGHTS.sum { |step, weight| weight * step_completion(step) }

      earned.round.clamp(MIN_REPORTED, MAX_REPORTED)
    end

    # Mirrors create_data's guards exactly — it delegates to the same predicates
    # the pipeline itself uses. If you change one, change the other.
    def step_done?(step)
      # lessons_rated? and similar_sounds_complete? read `data` directly, so they
      # blow up on a record whose data was never initialised.
      return false if data.blank?

      case step
      when :extract_lyrics        then progress_data["phrases"].present? && !progress_data["extract_lyrics_in_progress"]
      when :translate             then progress_data.dig("phrases", 0, "text_l2").present?
      when :add_token_translation then progress_data.dig("phrases", 0, "words", 0, "translation").present?
      when :add_lessons           then progress_data["lessons"].present?
      when :rate_lessons          then lessons_rated?
      when :add_similar_sound     then similar_sounds_complete?
      else false
      end
    end

    private

    def progress_data
      data || {}
    end

    # 0.0..1.0 for one step.
    def step_completion(step)
      return extract_lyrics_completion if step == :extract_lyrics

      step_done?(step) ? 1.0 : 0.0
    end

    # extract_lyrics saves phrases turn by turn, so it can report real progress
    # instead of flipping 0 -> 45 after several minutes. Coverage is how far into
    # the video we've transcribed.
    def extract_lyrics_completion
      return 1.0 if step_done?(:extract_lyrics)

      total = progress_data["video_length_seconds"].to_f
      return 0.0 unless total.positive?

      covered = Array(progress_data["phrases"])
                .filter_map { |phrase| Phrase.timestamp_to_seconds(phrase["timestamp_end"]) }
                .max
                .to_f

      (covered / total).clamp(0.0, 1.0)
    end
  end
end
