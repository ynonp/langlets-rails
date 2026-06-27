# Structured-output schema for the extract_lyrics LLM call. Forcing the model
# to emit JSON matching this shape (instead of free-form text) avoids the
# truncated/invalid JSON we used to get back and hand to WordTimingParser.
#
# Root must be an object, so the lines live under "lines". WordTimingParser
# unwraps that array. Timestamps are SRT strings ("HH:MM:SS,mmm").
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
end
