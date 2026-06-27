# Parses the word-level transcription JSON produced by the extract_lyrics LLM
# call (and the apt_word_timing.json verification fixture) into the internal
# phrase shape used throughout the Create Song pipeline.
#
# Input (array of line objects):
#   [{ "line_start": "00:00:06,500", "line_end": "00:00:07,800",
#      "line_text": "Apateu, apateu",
#      "words": [{ "word": "Apateu,", "start": "00:00:06,500", "end": "00:00:07,100" }, ...] }]
#
# Output (array of phrase hashes):
#   [{ "id" => "phrase_1", "text_l1" => "Apateu, apateu",
#      "timestamp" => "00:06.50", "timestamp_end" => "00:07.80",
#      "words" => [{ "text" => "Apateu,", "timestamp" => "00:06.50", "timestamp_end" => "00:07.10",
#                    "l1_start_index" => 0, "l1_end_index" => 6 }, ...] }]
class WordTimingParser
  def self.parse(json_text)
    new(json_text).parse
  end

  def initialize(json_text)
    @json_text = json_text
  end

  def parse
    entries = JSON.parse(strip_code_fences(@json_text))

    entries.each_with_index.map do |entry, idx|
      words = Array(entry["words"]).map do |w|
        {
          "text" => sanitize(w["word"]),
          "timestamp" => to_string_timestamp(w["start"]),
          "timestamp_end" => to_string_timestamp(w["end"])
        }
      end

      text_l1 = entry["line_text"].present? ? sanitize(entry["line_text"]) : words.map { |w| w["text"] }.join(" ")

      assign_l1_indices(words, text_l1)

      {
        "id" => "phrase_#{idx + 1}",
        "text_l1" => text_l1,
        "timestamp" => to_string_timestamp(entry["line_start"]),
        "timestamp_end" => to_string_timestamp(entry["line_end"]),
        "words" => words
      }
    end.reject { |phrase| phrase["text_l1"].blank? }
  end

  private

  # Locate each word inside text_l1 and record its character span as
  # l1_start_index / l1_end_index (end is inclusive, matching TokenTranslation's
  # character_index convention).
  #
  # The same word can appear several times in a line ("kissy face, kissy face"),
  # so the only reliable way to map a word object to its occurrence is the order
  # it is sung. We therefore walk the words in timestamp order, advancing a cursor
  # past each match, which guarantees the Nth occurrence in time maps to the Nth
  # occurrence in the text. Words that can't be found are left without indices and
  # are skipped downstream.
  def assign_l1_indices(words, text_l1)
    cursor = 0

    words.sort_by { |w| timestamp_seconds(w["timestamp"]) }.each do |word|
      text = word["text"].to_s
      next if text.blank?

      start_char = text_l1.index(text, cursor)
      next unless start_char

      end_char = start_char + text.length - 1
      cursor = end_char + 1

      word["l1_start_index"] = start_char
      word["l1_end_index"] = end_char
    end
  end

  # Parse the "MM:SS.ss" word timestamps we emit into float seconds for sorting.
  def timestamp_seconds(ts)
    return 0.0 if ts.blank?

    parts = ts.to_s.split(":")
    case parts.length
    when 3 then parts[0].to_f * 3600 + parts[1].to_f * 60 + parts[2].to_f
    when 2 then parts[0].to_f * 60 + parts[1].to_f
    else ts.to_f
    end
  end

  # The transcript becomes clickable text in the app; square brackets are
  # reserved for token-alignment markup, so strip them like the rest of the
  # pipeline does.
  def sanitize(text)
    text.to_s.gsub("[", "(").gsub("]", ")").strip
  end

  def strip_code_fences(text)
    text.to_s.strip
      .sub(/\A```(?:json)?\s*/i, "")
      .sub(/```\s*\z/, "")
      .strip
  end

  def to_string_timestamp(srt)
    Phrase.to_string_timestamp(srt_to_seconds(srt))
  end

  # Parse "HH:MM:SS,mmm" / "MM:SS,mmm" / "HH:MM:SS.mmm" into float seconds.
  def srt_to_seconds(srt)
    return 0.0 if srt.blank?

    normalized = srt.to_s.strip.tr(",", ".")
    parts = normalized.split(":")
    case parts.length
    when 3
      parts[0].to_f * 3600 + parts[1].to_f * 60 + parts[2].to_f
    when 2
      parts[0].to_f * 60 + parts[1].to_f
    else
      normalized.to_f
    end
  end
end
