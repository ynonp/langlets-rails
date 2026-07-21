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

    # What the Queue card calls each step. Phrased as what the user is waiting
    # for, not as the function that produces it — "add_token_translation" means
    # nothing to someone who just spent a credit.
    STEP_LABELS = {
      extract_lyrics: "Transcribing",
      translate: "Translating",
      add_token_translation: "Building vocab cards",
      add_lessons: "Writing lessons",
      rate_lessons: "Checking lessons",
      add_similar_sound: "Finding sound-alikes"
    }.freeze

    # Never report 0 (reads as "nothing is happening") and never report 100 until
    # the course is actually published — that's the job's call, not ours.
    MIN_REPORTED = 5
    MAX_REPORTED = 97

    def total_steps = STEP_WEIGHTS.size

    # The first step that isn't finished — what the pipeline is working on now.
    # Derived from `data` like everything else here, so it stays right across
    # resumes and out-of-order runs. Nil once every step is done.
    def current_step
      STEP_WEIGHTS.keys.find { |step| !step_done?(step) }
    end

    # "Transcribing · step 1 of 6". Nil when there's nothing left to do; the
    # caller decides what to show then, because "done" is the job's call.
    def current_step_label
      step = current_step
      return nil if step.nil?

      position = STEP_WEIGHTS.keys.index(step) + 1
      "#{STEP_LABELS.fetch(step)} · step #{position} of #{total_steps}"
    end

    def progress_percent
      earned = STEP_WEIGHTS.sum { |step, weight| weight * step_completion(step) }

      earned.round.clamp(MIN_REPORTED, MAX_REPORTED)
    end

    # These two used to live in the RateLessons / AddSimilarSound concerns,
    # next to the steps that produced them. The steps now run in the Deno
    # pipeline, but the data shape is unchanged and the pipeline guards its own
    # branches on the same keys (src/progress.ts), so the predicates moved here
    # rather than disappearing.
    def lessons_rated?
      progress_data["lesson_ratings"].present?
    end

    def similar_sounds_complete?
      progress_data["similar_sounds"].present?
    end

    # Mirrors the pipeline's branch guards: both sides read the same keys of
    # `data` to decide what still needs doing. If you change one, change the
    # other (pipeline/src/progress.ts).
    def step_done?(step)
      # lessons_rated? and similar_sounds_complete? read `data` directly, so they
      # blow up on a record whose data was never initialised.
      return false if data.blank?

      case step
      when :extract_lyrics        then progress_data["phrases"].present? && !progress_data["extract_lyrics_in_progress"]
      when :translate
        progress_data.dig("phrases", 0, "text_l2").present? ||
          progress_data["translations"].to_h.values.any? { |v| v.dig("phrases", 0, "text").present? }
      when :add_token_translation
        progress_data.dig("phrases", 0, "words", 0, "translation").present? ||
          progress_data["translations"].to_h.values.any? { |v| v.dig("phrases", 0, "words", 0).present? }
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
