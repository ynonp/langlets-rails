module ActivitiesHelper
  def timestamp_to_seconds(timestamp_mm_ss)
    minutes, seconds = timestamp_mm_ss.split(":").map(&:to_i)
    (minutes * 60) + seconds
  end

  def wrap_tokens_in_spans(phrase, attributes_map = {}, script: nil)
    if phrase.token_translations.empty?
      content_tag(:span, phrase.text_l1.to_s(script))
    else
      # Use the already loaded token_translations, sort them by l1_start_index
      loaded_tokens = phrase.token_translations.to_a.sort_by(&:l1_start_index)
      
      texts = loaded_tokens.inject([]) do |acc, val|
        l1_start_character_index = val.l1_characters_range(script).begin
        l1_end_character_index = val.l1_characters_range(script).end
        next_translated_token = {
          "l1" => phrase.text_l1.to_s(script)[val.l1_characters_range(script)],
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
              {"l1" => phrase.text_l1.to_s(script)[0...l1_start_character_index], "last_index" => l1_start_character_index},
              next_translated_token
            ]
          end
        elsif acc[-1]["last_index"] == l1_start_character_index
          [*acc, next_translated_token]
        else
          [
            *acc,
            {"l1" => phrase.text_l1.to_s(script)[acc[-1]["last_index"]...l1_start_character_index], "last_index" => l1_start_character_index},
            next_translated_token
          ]
        end
      end

      # Add the remaining text after the last token if there is any
      if texts.any? && texts.last["last_index"] < phrase.text_l1.to_s(script).length
        texts << {
          "l1" => phrase.text_l1.to_s(script)[texts.last["last_index"]...phrase.text_l1.to_s(script).length],
          "last_index" => phrase.text_l1.to_s(script).length
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
      phrase.text_l1.to_s
    else
      # Use the same approach as wrap_tokens_in_spans - build segments then join
      loaded_tokens = phrase.token_translations.to_a.sort_by(&:l1_start_index)
      
      texts = loaded_tokens.inject([]) do |acc, val|
        l1_start_character_index = val.l1_characters_range.begin
        l1_end_character_index = val.l1_characters_range.end
        original_text = phrase.text_l1.to_s[val.l1_characters_range]
        
        token_data = {
          original_text: original_text,
          similar_sound: val.similar_sound
        }.to_json
        
        # Create a blank span for this token
        blank_html = "<span class='blank-line underline text-gray-400' data-token='#{token_data.gsub("'", "&#39;")}'>________</span>"
        
        next_token_segment = {
          "content" => blank_html,
          "last_index" => l1_end_character_index,
          "is_token" => true
        }
        
        if acc.empty?
          if l1_start_character_index.zero?
            [*acc, next_token_segment]
          else
            [
              *acc,
              {"content" => phrase.text_l1.to_s[0...l1_start_character_index], "last_index" => l1_start_character_index, "is_token" => false},
              next_token_segment
            ]
          end
        elsif acc[-1]["last_index"] == l1_start_character_index
          [*acc, next_token_segment]
        else
          [
            *acc,
            {"content" => phrase.text_l1.to_s[acc[-1]["last_index"]...l1_start_character_index], "last_index" => l1_start_character_index, "is_token" => false},
            next_token_segment
          ]
        end
      end

      # Add the remaining text after the last token if there is any
      if texts.any? && texts.last["last_index"] < phrase.text_l1.to_s.length
        texts << {
          "content" => phrase.text_l1.to_s[texts.last["last_index"]...phrase.text_l1.to_s.length],
          "last_index" => phrase.text_l1.to_s.length,
          "is_token" => false
        }
      end
      
      # Join all the segments
      result = texts.map { |segment| segment["content"] }.join
      result.html_safe
    end
  end

  # Script-aware helper for getting token text
  def token_original_text(token_translation, script = nil)
    phrase = token_translation.phrase
    character_range = token_translation.l1_characters_range(script)
    phrase.text_l1.to_s(script)[character_range]
  end

  # Script-aware helper for getting phrase text in L1
  def phrase_text_l1(phrase, script = nil)
    phrase.text_l1.to_s(script)
  end

  # Script-aware helper for getting phrase text in L2
  def phrase_text_l2(phrase, script = nil)
    phrase.text_l2.to_s(script)
  end

  # Helper to prepare tokens data for match tokens activity with script support
  def prepare_tokens_for_matching(token_translations, script = nil)
    require 'set'
    
    # Filter out duplicates based on l1 text value or l2 text value
    seen_l1_texts = Set.new
    seen_l2_texts = Set.new
    filtered_token_translations = token_translations.select do |t|
      l1_text = token_original_text(t, script)
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
      l1_word = token_original_text(t, script)
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

  # Helper to prepare phrases list for sorting activity with script support
  def prepare_phrases_for_sorting(phrases, script = nil)
    phrases.ordered_by_timestamp.first(4).map { |p| phrase_text_l1(p, script) }
  end
end
