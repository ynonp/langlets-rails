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
#                    "l1_start_index" => 0, "l1_end_index" => 5 }, ...] }]
class WordTimingParser
  # Accepts either a raw JSON string (the apt_word_timing.json fixture, or any
  # legacy free-form LLM text) or an already-parsed structure from a structured
  # output call: an Array of line hashes, or a Hash wrapping them under "lines".
  def self.parse(input)
    new(input).parse
  end

  # Recompute l1_start_index / l1_end_index on already-parsed phrase words using
  # the current matching logic. Used to repair stored CreateSongProgress data
  # that was parsed before locate_word understood line-final punctuation.
  # Mutates each word in place.
  def self.reindex_phrase_words(words, text_l1)
    new("[]").send(:assign_l1_indices, Array(words), text_l1.to_s)
  end

  def initialize(input)
    @input = input
  end

  def parse
    entries = normalize_entries(@input)

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

      span = locate_word(text, text_l1, cursor)
      next unless span

      start_char, end_char = span
      cursor = end_char + 1

      word["l1_start_index"] = start_char
      word["l1_end_index"] = end_char
    end
  end

  # Find a word inside text_l1 at or after cursor. We match on the word with any
  # surrounding punctuation stripped: the transcription attaches punctuation that
  # isn't part of the word itself (a trailing comma on a line's final word,
  # quotes, etc.), and the token span should cover just the word -- "symphony"
  # rather than "symphony,". Returns [start_index, end_index] (end inclusive) or
  # nil when the word can't be located. Words that are pure punctuation are
  # skipped.
  def locate_word(text, text_l1, cursor)
    needle = text.gsub(/\A[[:punct:]]+|[[:punct:]]+\z/, "")
    return nil if needle.blank?

    idx = text_l1.index(needle, cursor)
    idx ? [ idx, idx + needle.length - 1 ] : nil
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

  # Coerce the constructor input into the array of line hashes we iterate over.
  # Strings are JSON-parsed (fixtures / legacy free-form responses); structured
  # output hands us a Hash keyed by "lines" (or a bare Array).
  def normalize_entries(input)
    data = input.is_a?(String) ? JSON.parse(strip_code_fences(input)) : input

    case data
    when Array then data
    when Hash  then Array(data["lines"] || data[:lines])
    else            []
    end
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
