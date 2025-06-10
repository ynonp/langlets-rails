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
      
      texts = loaded_tokens.inject([]) do |acc, val|
        next_translated_token = {
          "l1" => phrase.text_l1[val.l1_start_index...val.l1_end_index],
          "l2" => val.translation,
          "last_index" => val.l1_end_index,
          "token_id" => val.id,
          "audio_url" => val&.l1_audio.persisted? ? url_for(val.l1_audio) : nil,
        }
        if acc.empty?
          if val.l1_start_index.zero?
            [*acc, next_translated_token]
          else
            [
              *acc,
              {"l1" => phrase.text_l1[0...val.l1_start_index], "last_index" => val.l1_start_index},
              next_translated_token
            ]
          end
        elsif acc[-1]["last_index"] == val.l1_start_index
          [*acc, next_translated_token]
        else
          [
            *acc,
            {"l1" => phrase.text_l1[acc[-1]["last_index"]...val.l1_start_index], "last_index" => val.l1_start_index},
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
                      span_content,
                      val["l2"].present? ? attributes_map : {})
        else
          span_content
        end
      end)
    end
  end
  
  def render_phrase_with_blanks(phrase)
    text = phrase['text_l1']
    tokens = phrase['token_translations'] || []
    
    # Sort tokens by start_index in descending order to avoid position shifts
    tokens_sorted = tokens.sort_by { |t| -t['start_index'] }
    
    tokens_sorted.each do |token|
      start_index = token['start_index']
      end_index = token['end_index']
      original_text = token['original_text']
      similar_sound = token['similar_sound']
      
      token_data = {
        original_text: original_text,
        similar_sound: similar_sound
      }.to_json
      
      # Create a blank line with the same width as the original text
      blank_html = "<span class='blank-line underline text-gray-400' data-token='#{token_data.gsub("'", "&#39;")}'>________</span>"
      
      # Replace the token with a blank line
      text = text[0...start_index] + blank_html + text[end_index..]
    end
    
    text.html_safe
  end
end
