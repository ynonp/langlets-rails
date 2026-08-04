require "test_helper"

module CreateSong
  class ProgressReportingTest < ActiveSupport::TestCase
    setup do
      @progress = CreateSongProgress.new(
        youtubeurl: "https://www.youtube.com/watch?v=kJQP7kiw5Fk",
        clip_language: "Spanish",
        data: {}
      )
    end

    test "reports a floor rather than zero before anything has happened" do
      assert_equal ProgressReporting::MIN_REPORTED, @progress.progress_percent
    end

    test "never reports 100 — publishing the course is the job's call" do
      @progress.data = finished_data

      assert_equal ProgressReporting::MAX_REPORTED, @progress.progress_percent
      assert_operator @progress.progress_percent, :<, 100
    end

    # The bug this guards is the one users actually notice: a progress bar that
    # goes backwards.
    test "progress never decreases as the pipeline advances" do
      percents = pipeline_stages.map do |name, data|
        @progress.data = data
        [ name, @progress.progress_percent ]
      end

      percents.each_cons(2) do |(prev_name, prev), (name, current)|
        assert_operator current, :>=, prev,
                        "progress went backwards: #{prev_name} was #{prev}%, #{name} is #{current}%"
      end
    end

    # Below the floor the early stages are deliberately indistinguishable (an
    # empty run and a barely-started transcription both report MIN_REPORTED), but
    # from the end of transcription on, every step has to visibly move the bar.
    test "each completed step visibly moves the bar" do
      values = pipeline_stages.drop(2).map { |_, data| @progress.data = data; @progress.progress_percent }

      assert_equal values, values.uniq, "steps should be distinguishable: #{values.inspect}"
    end

    # extract_lyrics is 45% of the bar and takes minutes. Without a denominator it
    # would sit at the floor the whole time and read as broken.
    test "extract_lyrics earns partial credit as transcription covers the video" do
      @progress.data = {
        "extract_lyrics_in_progress" => true,
        "video_length_seconds" => 200.0,
        "phrases" => [ { "timestamp" => "00:00", "timestamp_end" => "01:40" } ] # half of 200s
      }

      # ~50% of the 45-point step, plus nothing else yet.
      assert_in_delta 22, @progress.progress_percent, 2
    end

    test "extract_lyrics coverage grows monotonically with the transcript" do
      covered = [ "00:10", "00:50", "01:40", "03:00" ].map do |timestamp_end|
        @progress.data = {
          "extract_lyrics_in_progress" => true,
          "video_length_seconds" => 200.0,
          "phrases" => [ { "timestamp" => "00:00", "timestamp_end" => timestamp_end } ]
        }
        @progress.progress_percent
      end

      assert_equal covered.sort, covered, "coverage should only increase: #{covered.inspect}"
    end

    test "coverage cannot exceed the step's weight even if the transcript overruns" do
      @progress.data = {
        "extract_lyrics_in_progress" => true,
        "video_length_seconds" => 10.0,
        "phrases" => [ { "timestamp" => "00:00", "timestamp_end" => "99:00" } ]
      }

      # Capped at the 45-point weight, not beyond it.
      assert_operator @progress.progress_percent, :<=, 45
    end

    test "falls back to the floor when the video length is unknown" do
      @progress.data = {
        "extract_lyrics_in_progress" => true,
        "phrases" => [ { "timestamp" => "00:00", "timestamp_end" => "01:00" } ]
      }

      assert_equal ProgressReporting::MIN_REPORTED, @progress.progress_percent
    end

    # A finished-but-unflagged transcription must not be mistaken for a partial
    # one — this is the same distinction create_data's guard makes.
    test "clearing the in-progress flag completes the step" do
      base = {
        "video_length_seconds" => 200.0,
        "phrases" => [ { "timestamp" => "00:00", "timestamp_end" => "00:10" } ]
      }

      @progress.data = base.merge("extract_lyrics_in_progress" => true)
      mid_run = @progress.progress_percent

      @progress.data = base.merge("extract_lyrics_in_progress" => false)
      finished = @progress.progress_percent

      assert_operator finished, :>, mid_run
      assert_equal 45, finished
    end

    test "step_done? mirrors create_data's guards" do
      @progress.data = finished_data

      %i[extract_lyrics translate add_token_translation add_lessons rate_lessons add_similar_sound].each do |step|
        assert @progress.step_done?(step), "expected #{step} to be done"
      end
    end

    test "tolerates nil data" do
      @progress.data = nil

      assert_nothing_raised { @progress.progress_percent }
    end

    private

    # Ordered as create_data runs them.
    def pipeline_stages
      transcribing = {
        "extract_lyrics_in_progress" => true,
        "video_length_seconds" => 200.0,
        "phrases" => [ { "timestamp" => "00:00", "timestamp_end" => "00:20" } ]
      }
      transcribed = transcribing.merge("extract_lyrics_in_progress" => false)
      translated  = transcribed.merge(
        "phrases" => [ { "timestamp" => "00:00", "timestamp_end" => "00:20",
                         "text_l1" => "hola", "text_l2" => "hello" } ]
      )
      tokenised = translated.merge(
        "phrases" => [ { "timestamp" => "00:00", "timestamp_end" => "00:20",
                         "text_l1" => "hola", "text_l2" => "hello",
                         "words" => [ { "text" => "hola", "translation" => "hello" } ] } ]
      )
      lessons  = tokenised.merge("lessons" => [ { "title" => "Lesson 1" } ])
      rated    = lessons.merge("lesson_ratings" => [ 1 ])
      sounded  = rated.merge("similar_sounds" => "hola [ola]")

      [
        [ "empty",        {} ],
        [ "transcribing", transcribing ],
        [ "transcribed",  transcribed ],
        [ "translated",   translated ],
        [ "tokenised",    tokenised ],
        [ "lessons",      lessons ],
        [ "rated",        rated ],
        [ "similar",      sounded ]
      ]
    end

    def finished_data
      pipeline_stages.last.last
    end
  end
end
