module ActivitiesHelper
  def timestamp_to_seconds(timestamp_mm_ss)
    minutes, seconds = timestamp_mm_ss.split(":").map(&:to_i)
    (minutes * 60) + seconds
  end

  def wrap_tokens_in_spans(phrase, attributes_map = {})
    if phrase.token_translations.empty?
      content_tag(:span, phrase.text_l1)
    else
      # Use the already loaded token_translations, sort them by l1_start_index
      loaded_tokens = phrase.token_translations.to_a.sort_by(&:l1_start_index)
      
      # Convert word indices to character indices
      words = phrase.text_l1.split
      
      texts = loaded_tokens.inject([]) do |acc, val|
        # Calculate character positions from word positions
        l1_start_character_index = words[0...val.l1_start_index].join(' ').length
        l1_start_character_index += 1 if val.l1_start_index > 0 # Add space before word
        l1_end_character_index = l1_start_character_index + words[val.l1_start_index..val.l1_end_index].join(' ').length
        
        next_translated_token = {
          "l1" => phrase.text_l1[l1_start_character_index...l1_end_character_index],
          "l2" => val.translation,
          "last_index" => l1_end_character_index,
          "token_id" => val.id,
          "audio_url" => val&.l1_audio.persisted? ? url_for(val.l1_audio) : nil,
        }
        if acc.empty?
          if l1_start_character_index.zero?
            [*acc, next_translated_token]
          else
            [
              *acc,
              {"l1" => phrase.text_l1[0...l1_start_character_index], "last_index" => l1_start_character_index},
              next_translated_token
            ]
          end
        elsif acc[-1]["last_index"] == l1_start_character_index
          [*acc, next_translated_token]
        else
          [
            *acc,
            {"l1" => phrase.text_l1[acc[-1]["last_index"]...l1_start_character_index], "last_index" => l1_start_character_index},
            next_translated_token
          ]
        end
      end

      # Add the remaining text after the last token if there is any
      if texts.any? && texts.last["last_index"] < phrase.text_l1.length
        texts << {
          "l1" => phrase.text_l1[texts.last["last_index"]...phrase.text_l1.length],
          "last_index" => phrase.text_l1.length
        }
      end
  
      safe_join(texts.map do |val|
        audio_url = val["audio_url"]
        span_content = content_tag(:span,
                    val["l1"],
                    {**(val["l2"].present? ? attributes_map : {}),
                     data: { **(attributes_map[:data] || {}),
                             translation: val["l2"],
                             token_id: val["token_id"],
                             audio_url: audio_url
                     }
                    })
        
        if audio_url.present?
          content_tag(:div, 
                      span_content + content_tag(:audio, "", src: audio_url, preload: "none"),
                      val["l2"].present? ? attributes_map : {})
        else
          span_content
        end
      end)
    end
  end
  
  def render_phrase_with_blanks(phrase)
    if phrase.token_translations.empty?
      phrase.text_l1
    else
      # Use word indices to create blanks
      words = phrase.text_l1.split
      loaded_tokens = phrase.token_translations.to_a.sort_by(&:l1_start_index)
      
      result_words = words.dup
      
      # Replace token words with blanks (process in reverse to maintain indices)
      tokens_with_similar = loaded_tokens.select { |t| similar_sounds_for_token(phrase, t).present? }
      token_to_blank = tokens_with_similar.sample

      loaded_tokens.reverse.each do |val|
        similar = similar_sounds_for_token(phrase, val)
        next if similar.blank?
        next unless val == token_to_blank

        token_data = {
          original_text: words[val.l1_start_index..val.l1_end_index].join(' '),
          similar_sound: similar
        }.to_json
        
        # Create a blank span for this token
        blank_html = "<span class='mx-2 inline-block blank-line underline text-gray-400' data-token='#{token_data.gsub("'", "&#39;")}'>________</span>"
        
        # Replace the word range with the blank
        result_words[val.l1_start_index..val.l1_end_index] = [blank_html]
      end
      
      result_words.join(' ').html_safe
    end
  end

  # Helper for getting token text
  def token_original_text(token_translation)
    words = token_translation.phrase.text_l1.split
    words[token_translation.l1_start_index..token_translation.l1_end_index].join(' ')
  end

  # Helper for getting phrase text in L1
  def phrase_text_l1(phrase)
    phrase.text_l1
  end

  # Helper for getting phrase text in L2
  def phrase_text_l2(phrase)
    phrase.text_l2
  end

  # Helper to prepare tokens data for match tokens activity
  def prepare_tokens_for_matching(token_translations)
    require 'set'
    
    # Filter out duplicates based on l1 text value or l2 text value
    seen_l1_texts = Set.new
    seen_l2_texts = Set.new
    filtered_token_translations = token_translations.select do |t|
      l1_text = token_original_text(t)
      l2_text = t.translation
      
      # Skip if we've already seen this l1 or l2 text
      if seen_l1_texts.include?(l1_text) || seen_l2_texts.include?(l2_text)
        false
      else
        seen_l1_texts.add(l1_text)
        seen_l2_texts.add(l2_text)
        true
      end
    end
    
    # Map each token translation to [word in l1, translation in l2, audio]
    filtered_token_translations.map do |t|
      l1_word = token_original_text(t)
      audio_url = t.l1_audio.attached? ? 
        Rails.application.routes.url_helpers.rails_blob_path(t.l1_audio, only_path: true) : nil
      
      {
        l1_word: l1_word,
        l2_translation: t.translation,
        audio_url: audio_url,
        id: t.id
      }
    end
  end

  # Helper to prepare phrases list for sorting activity
  def prepare_phrases_for_sorting(phrases)
    # phrases is already an array from first(4), so just map it
    phrases.map { |p| phrase_text_l1(p) }
  end

  # Helper to prepare phrases data for language alignment activity
  def prepare_phrases_with_tokens_for_alignment(phrases_with_tokens)
    phrases_with_tokens.filter_map do |phrase_data|
      phrase = phrase_data[:phrase]
      tokens = phrase_data[:tokens]
      
      next unless tokens.present?
      
      # Get text directly
      l1_text = phrase_text_l1(phrase)
      l2_text = phrase_text_l2(phrase)
      
      # Use token indices directly (they are already word indices)
      tokens_with_ranges = tokens.map do |token_data|
        # Convert word indices to character indices for display
        words = phrase.text_l1.split
        l1_start_char = words[0...token_data[:l1_start_index]].join(' ').length
        l1_start_char += 1 if token_data[:l1_start_index] > 0 # Add space before word
        l1_end_char = l1_start_char + words[token_data[:l1_start_index]..token_data[:l1_end_index]].join(' ').length - 1
        
        # Similar for L2
        l2_words = phrase.text_l2.split
        l2_start_char = l2_words[0...token_data[:l2_start_index]].join(' ').length
        l2_start_char += 1 if token_data[:l2_start_index] > 0
        l2_end_char = l2_start_char + l2_words[token_data[:l2_start_index]..token_data[:l2_end_index]].join(' ').length - 1
        
        token_data.merge({
          l1_start_index: l1_start_char,
          l1_end_index: l1_end_char,
          l2_start_index: l2_start_char,
          l2_end_index: l2_end_char
        })
      end
      
      {
        original_text: l1_text,
        translation: l2_text,
        tokens: tokens_with_ranges
      }
    end
  end

  # Prepare flashcards for FlashcardActivity
  def prepare_flashcards_for_tokens(token_translations)
    token_translations = token_translations.to_a
    l1_texts = token_translations.map { |t| token_original_text(t) }.uniq

    cards = token_translations.map do |t|
      l1_word = token_original_text(t)
      l2_translation = t.translation
      audio_url = t.l1_audio.attached? ? Rails.application.routes.url_helpers.rails_blob_path(t.l1_audio, only_path: true) : nil

      distractor_pool = (l1_texts + all_lesson_texts).uniq - [l1_word]
      distractors = distractor_pool.sample(3)
      options = ([l1_word] + distractors).uniq.shuffle

      # Map option text to audio URLs if available
      audio_map = token_translations.each_with_object({}) do |tt, memo|
        key = token_original_text(tt)
        memo[key] = tt.l1_audio.attached? ? Rails.application.routes.url_helpers.rails_blob_path(tt.l1_audio, only_path: true) : nil
      end

      options_audio_urls = options.map { |opt| audio_map[opt] }

      phrase_words = t.phrase.text_l1.split
      phrase_words[t.l1_start_index..t.l1_end_index] = ['________']
      phrase_with_blank = phrase_words.join(' ')

      {
        id: t.id,
        phrase_html: phrase_with_blank,
        translation: l2_translation,
        correct: l1_word,
        options: options,
        options_audio_urls: options_audio_urls,
        audio_url: audio_url
      }
    end

    cards
  end

  private

  def similar_sounds_for_token(phrase, token_translation)
    return nil unless phrase.respond_to?(:similar_sounds)

    matching = phrase.similar_sounds.select do |ss|
      ss.start_word_index >= token_translation.l1_start_index && ss.end_word_index <= token_translation.l1_end_index
    end

    return nil if matching.blank?

    matching.map(&:replacement_text)
  end
end
