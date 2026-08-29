module Vocabulary
  # Creates a vocabulary entry the user typed themselves, from the Vocabulary
  # tab's "Add a word" screen.
  #
  # A saved word is always a span inside a phrase — that is what lets "No time
  # left" and "turn left here" be two entries for the same word. A custom
  # phrase belongs directly to the user who typed it; imported/course phrases
  # belong to a playable Medium instead.
  class CustomEntry
    # A word boundary for trimming the punctuation a user's selection sweeps up:
    # picking "quick," should save "quick".
    LEADING_JUNK = /\A[^\p{L}\p{N}]+/u
    TRAILING_JUNK = /[^\p{L}\p{N}]+\z/u

    class Error < StandardError; end

    # sentence:    the phrase the word was met in, as typed
    # language:    the Language the phrase is in (what the user is learning)
    # token_range: inclusive range of whitespace-token indexes the user picked
    # translation: what the picked span means *in this phrase*
    def initialize(user:, sentence:, language:, token_range:, translation:, translation_language: nil)
      @user = user
      @sentence = sentence.to_s.split.join(" ")
      @language = language
      @token_range = token_range
      @translation = translation.to_s.strip
      @translation_language = translation_language || Current.translation_language
    end

    def call
      validate!

      PhraseTokenUser.transaction do
        phrase = Phrase.create!(user: @user, l1: @language, text_l1: @sentence)
        token = phrase.phrase_tokens.create!(
          l1_start_index: span.first,
          l1_end_index: span.last,
          index_type: :character_index
        )
        token.token_translations.create!(language: @translation_language, translation: @translation)
        @user.phrase_token_users.create!(phrase_token: token, language: @translation_language)
      end
    end

    # The picked text after punctuation is trimmed — what the entry will call
    # itself. Used by the form to echo the selection back before saving.
    def picked_text = @sentence[span.first..span.last].to_s

    private

    def validate!
      raise Error, "Type the phrase you met the word in." if @sentence.blank?
      raise Error, "Pick the word you are learning." if @token_range.blank?
      raise Error, "Add what the word means here." if @translation.blank?
      raise Error, "Choose the language of the phrase." if @language.blank?
      raise Error, "No translation language available." if @translation_language.blank?
      raise Error, "Pick the word you are learning." if span.nil?
    end

    # Inclusive character offsets of the picked span inside the normalized
    # sentence. nil when the selection lands entirely on punctuation.
    def span
      return @span if defined?(@span)

      @span = compute_span
    end

    def compute_span
      words = @sentence.split
      first_index = @token_range.first
      last_index = @token_range.last
      return nil if first_index.nil? || last_index.nil?
      return nil if first_index.negative? || last_index >= words.length || first_index > last_index

      # The sentence is whitespace-normalized above, so words rejoin with a
      # single space and these offsets are exact.
      start_offset = first_index.zero? ? 0 : words.first(first_index).join(" ").length + 1
      end_offset = words.first(last_index).join(" ").length + (last_index.zero? ? 0 : 1) + words[last_index].length - 1

      picked = @sentence[start_offset..end_offset].to_s
      leading = picked[LEADING_JUNK]&.length.to_i
      trailing = picked[TRAILING_JUNK]&.length.to_i
      return nil if leading + trailing >= picked.length

      [ start_offset + leading, end_offset - trailing ]
    end
  end
end
