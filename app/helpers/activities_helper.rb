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
end
