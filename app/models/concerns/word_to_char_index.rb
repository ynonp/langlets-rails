# Token spans are stored either as character offsets or word offsets (see
# PhraseToken#index_type). This is the single conversion from a word offset to
# the character position of that word in text, matching String#split's
# whitespace handling. Words are rejoined with a single space, so texts with
# runs of whitespace resolve to normalized positions, not original ones.
module WordToCharIndex
  # Character position of the word's first character; with inclusive: true, of
  # its last character. Returns nil for a missing index, blank text, or an
  # index outside the text's words.
  def word_to_char_index(text, word_index, inclusive: false)
    return nil if word_index.nil? || text.blank?

    words = text.split
    return nil if word_index.negative? || word_index >= words.length

    position = word_index.zero? ? 0 : words.first(word_index).join(" ").length + 1
    inclusive ? position + words[word_index].length - 1 : position
  end
end
