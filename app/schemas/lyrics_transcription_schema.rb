# Structured-output schema for the extract_lyrics LLM call. Forcing the model
# to emit JSON matching this shape (instead of free-form text) avoids the
# truncated/invalid JSON we used to get back and hand to WordTimingParser.
#
# Root must be an object, so the lines live under "lines". WordTimingParser
# unwraps that array. Timestamps are SRT strings ("HH:MM:SS,mmm").
#
# Each call returns at most 30 lines; "has_more" tells the pipeline whether the
# video still has content past the last returned line, so ExtractLyrics can make
# a follow-up call to fetch the next batch.
class LyricsTranscriptionSchema < RubyLLM::Schema
  array :lines do
    object do
      string :line_start, description: "Start of the line, e.g. 00:00:06,500"
      string :line_end, description: "End of the line, e.g. 00:00:07,800"
      string :line_text, description: "The transcribed line text"

      array :words do
        object do
          string :word, description: "A single word as sung"
          string :start, description: "Word start, e.g. 00:00:06,500"
          string :end, description: "Word end, e.g. 00:00:07,100"
        end
      end
    end
  end

  boolean :has_more, description: "true if there is more spoken/sung content in the video after the last line you returned that you did NOT include (because of the 30-line cap); false if you have transcribed everything up to the end of the video."

  string :video_length, description: "The total running length of the whole video as an SRT timestamp (HH:MM:SS,mmm), e.g. 00:03:45,000. This is the duration of the entire clip, independent of how many lines you returned, and must be identical in every response for this video."
end
