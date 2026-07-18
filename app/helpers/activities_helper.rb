module ActivitiesHelper
  # NOTE: intentionally NOT the same as HasTimestamp.timestamp_to_seconds. This
  # helper parses a 3-segment value as "MM:SS:mmm" (the third field is
  # milliseconds), whereas HasTimestamp reads three segments as "HH:MM:SS". The
  # two are not interchangeable, so this stays a separate parser.
  def timestamp_to_seconds(timestamp)
    parts = timestamp.split(":")
    case parts.length
    when 2
      minutes, seconds = parts
      (minutes.to_f * 60) + seconds.to_f
    when 3
      minutes, seconds, milliseconds = parts
      milliseconds = milliseconds.to_i
      milliseconds *= 10 if milliseconds.to_s.length == 2
      (minutes.to_f * 60) + seconds.to_f + (milliseconds.to_f / 1000)
    else
      0
    end
  end

  # True when any token in the given phrases carries a start timestamp, meaning
  # the video player can use karaoke-style per-word highlighting. Older songs
  # (tokens without timestamps) return false and fall back to line highlighting.
  def word_timing_enabled?(phrases)
    Array(phrases).any? do |phrase|
      phrase.phrase_tokens.any? { |t| t.start_timestamp.present? }
    end
  end

  def wrap_tokens_in_spans(phrase, attributes_map = {})
    if phrase.phrase_tokens.empty?
      content_tag(:span, phrase.text_l1)
    else
      all_tokens = phrase.phrase_tokens.to_a.sort_by(&:l1_start_index)

      loaded_tokens = filter_overlapping_tokens(all_tokens)

      texts = loaded_tokens.inject([]) do |acc, val|
        l1_start = val.l1_start_index
        l1_end = val.l1_end_index

        next_translated_token = {
          "l1" => phrase.text_l1[l1_start..l1_end],
          "l2" => val.translation,
          "last_index" => l1_end,
          "token_id" => val.id,
          "token_start" => val.start_timestamp_seconds,
          "token_end" => val.end_timestamp_seconds,
          "audio_url" => val.l1_audio_url
        }
        if acc.empty?
          if l1_start.zero?
            [ *acc, next_translated_token ]
          else
            [
              *acc,
              { "l1" => phrase.text_l1[0...l1_start], "last_index" => l1_start },
              next_translated_token
            ]
          end
        elsif acc[-1]["last_index"] == l1_start - 1
          [ *acc, next_translated_token ]
        else
          [
            *acc,
            { "l1" => phrase.text_l1[acc[-1]["last_index"] + 1...l1_start], "last_index" => l1_start },
            next_translated_token
          ]
        end
      end

      if texts.any? && texts.last["last_index"] < phrase.text_l1.length - 1
        texts << {
          "l1" => phrase.text_l1[texts.last["last_index"] + 1..phrase.text_l1.length],
          "last_index" => phrase.text_l1.length
        }
      end

      safe_join(texts.map do |val|
        audio_url = val["audio_url"]
        content_tag(:span,
                    val["l1"],
                    { **(val["l2"].present? ? attributes_map : {}),
                     data: { **(attributes_map[:data] || {}),
                             translation: val["l2"],
                             token_id: val["token_id"],
                             token_start: val["token_start"],
                             token_end: val["token_end"],
                             audio_url: audio_url,
                             # Opt into click-to-play via the audio-cache controller
                             audio_click: (true if audio_url.present?)
                     }
                    })
      end)
    end
  end

  def render_phrase_with_blanks(phrase)
    if phrase.phrase_tokens.empty?
      phrase.text_l1
    else
      loaded_tokens = phrase.phrase_tokens.to_a.sort_by(&:l1_start_index)
      tokens_with_similar = loaded_tokens.select { |t| similar_sounds_for_token(phrase, t).present? }
      token_to_blank = tokens_with_similar.sample

      result = ""
      current_pos = 0

      loaded_tokens.each do |val|
        similar = similar_sounds_for_token(phrase, val)
        next if similar.blank?
        next unless val == token_to_blank

        token_start = val.l1_start_index
        token_end = val.l1_end_index

        if current_pos < token_start
          result += phrase.text_l1[current_pos...token_start]
        end

        token_data = {
          original_text: val.original_text,
          similar_sound: similar
        }.to_json

        result += "<span class='mx-2 inline-block blank-line underline text-gray-400' data-token='#{token_data.gsub("'", "&#39;")}'>________</span>"
        current_pos = token_end + 1
      end

      if current_pos < phrase.text_l1.length
        result += phrase.text_l1[current_pos..phrase.text_l1.length]
      end

      result.html_safe
    end
  end

  def prepare_tokens_for_matching(token_translations)
    require "set"

    seen_l1_texts = Set.new
    seen_l2_texts = Set.new
    filtered_token_translations = token_translations.select do |t|
      l1_text = t.original_text
      l2_text = t.translation

      if seen_l1_texts.include?(l1_text) || seen_l2_texts.include?(l2_text)
        false
      else
        seen_l1_texts.add(l1_text)
        seen_l2_texts.add(l2_text)
        true
      end
    end

    filtered_token_translations.map do |t|
      l1_word = t.original_text
      audio_url = t.l1_audio_url

      {
        l1_word: l1_word,
        l2_translation: t.translation,
        audio_url: audio_url,
        id: t.id
      }
    end
  end

  def phrase_text_l1(phrase)
    phrase.text_l1
  end

  def phrase_text_l2(phrase)
    phrase.text_l2
  end

  def prepare_phrases_for_sorting(phrases)
    phrases.map { |p| phrase_text_l1(p) }
  end

  def prepare_phrases_with_tokens_for_alignment(phrases_with_tokens)
    phrases_with_tokens.filter_map do |phrase_data|
      phrase = phrase_data[:phrase]
      tokens = phrase_data[:tokens]

      next unless tokens.present?

      l1_text = phrase_text_l1(phrase)
      l2_text = phrase_text_l2(phrase)

      tokens_with_ranges = tokens.map do |token_data|
        token_data.merge({
          l1_start_index: token_data[:l1_start_index],
          l1_end_index: token_data[:l1_end_index],
          l2_start_index: token_data[:l2_start_index],
          l2_end_index: token_data[:l2_end_index]
        })
      end

      {
        original_text: l1_text,
        translation: l2_text,
        tokens: tokens_with_ranges
      }
    end
  end

  def prepare_flashcards_for_tokens(token_translations, unique_song_words)
    token_translations = token_translations.to_a
    l1_texts = token_translations.map { |t| t.original_text }.uniq

    cards = token_translations.map do |t|
      l1_word = t.original_text
      l2_translation = t.translation
      audio_url = t.l1_audio_url

      distractors_pool = l1_texts - [ l1_word ]
      distractors = unique_song_words.reject { |w| w.downcase == l1_word.downcase }.sample(3)
      options = ([ l1_word ] + distractors).shuffle

      token_start = t.l1_start_index
      token_end = t.l1_end_index
      phrase_text = t.phrase.text_l1

      blanked_text = phrase_text.dup
      if token_start == 0
        blanked_text = "________" + blanked_text[token_end + 1..]
      else
        blanked_text[token_start..token_end] = "________"
      end

      {
        id: t.id,
        phrase_html: blanked_text,
        translation: l2_translation,
        correct: l1_word,
        options: options,
        audio_url: audio_url
      }
    end

    cards
  end

  private

  def filter_overlapping_tokens(tokens)
    return tokens if tokens.empty? || tokens.length == 1

    sorted = tokens.sort_by { |t| [ t.l1_start_index, -(t.l1_end_index - t.l1_start_index) ] }

    filtered = []
    sorted.each do |token|
      is_contained = filtered.any? do |accepted_token|
        accepted_token.l1_start_index <= token.l1_start_index &&
          accepted_token.l1_end_index >= token.l1_end_index &&
          accepted_token.id != token.id
      end

      filtered.reject! do |accepted_token|
        token.l1_start_index <= accepted_token.l1_start_index &&
          token.l1_end_index >= accepted_token.l1_end_index &&
          accepted_token.id != token.id
      end

      filtered << token unless is_contained
    end

    filtered.sort_by(&:l1_start_index)
  end

  def similar_sounds_for_token(phrase, token_translation)
    return nil unless phrase.respond_to?(:similar_sounds)

    token_start_word = char_index_to_word_index(token_translation.l1_start_index, phrase.text_l1)
    token_end_word = char_index_to_word_index(token_translation.l1_end_index, phrase.text_l1, inclusive: true)

    matching = phrase.similar_sounds.select do |ss|
      ss.start_word_index >= token_start_word && ss.end_word_index <= token_end_word
    end

    return nil if matching.blank?

    matching.map(&:replacement_text)
  end

  def char_index_to_word_index(char_index, text, inclusive: false)
    return nil if char_index.nil? || text.nil?
    return 0 if char_index == 0

    words = text.split
    current_pos = 0

    words.each_with_index do |word, idx|
      word_start = idx == 0 ? 0 : words[0...idx].join(" ").length + 1
      word_end = word_start + word.length - 1

      if char_index >= word_start && char_index <= word_end
        return idx
      end
    end

    words.length - 1
  end
end
