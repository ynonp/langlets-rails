module Ai
  class CreateSong
    attr_accessor :youtubeurl, :lyrics_url, :clip_language, :translation_language, :data, :gemini, :openai, :claude, :song_name

    CreateSongData = Data.define(
      :phrases,
      :lessons,
    )

    LessonData = Data.define(
      :title,
      :description,
      :start_timestamp,
      :end_timestamp,
      :phrases
    )

    def initialize(song_name, youtubeurl, clip_language, translation_language, lyrics_url)
      @lyrics_url = lyrics_url
      @song_name = song_name
      @clip_language = clip_language
      @translation_language = translation_language
      @youtubeurl = youtubeurl
      @gemini = Langchain::LLM::GoogleGemini.new(
        api_key: Rails.application.credentials.google_api_key,
        default_options: { temperature: 0.7, chat_model: 'gemini-2.5-pro-preview-05-06' },
      )
      @gemini.read_timeout = 600
      @flash = Langchain::LLM::GoogleGemini.new(
        api_key: Rails.application.credentials.google_api_key,
        default_options: { temperature: 0.4, chat_model: 'gemini-2.5-flash-preview-05-20' },
      )
      @flash.read_timeout = 600
      @openai = Langchain::LLM::OpenAI.new(
        api_key: Rails.application.credentials.openai_key,
        default_options: { chat_model: "o4-mini" }
      )
      @claude = Langchain::LLM::Anthropic.new(
        api_key: Rails.application.credentials.anthropic_api_key,
        default_options: { chat_model: 'claude-sonnet-4-0' }
      )
    end

    def run
      progress = CreateSongProgress.find_by(youtubeurl:, clip_language:, translation_language:)
      create_phrases if progress.nil? || progress.step.nil?

      progress = CreateSongProgress.find_by(youtubeurl:, clip_language:, translation_language:)
      create_lessons if progress.create_phrases?

      progress = CreateSongProgress.find_by(youtubeurl:, clip_language:, translation_language:)      
      create_token_translations if progress.create_lessons?

      progress = CreateSongProgress.find_by(youtubeurl:, clip_language:, translation_language:)      
      create_listening_activities if progress.create_token_translations?

      progress = CreateSongProgress.find_by(youtubeurl:, clip_language:, translation_language:)      
      create_language_alignment_activities if progress.create_listening_activities?

      progress = CreateSongProgress.find_by(youtubeurl:, clip_language:, translation_language:)      
      create_audio if progress.create_language_alignment_activities?

      progress = CreateSongProgress.find_by(youtubeurl:, clip_language:, translation_language:)            
      save_progress(:ready) if progress.create_audio?

      progress = CreateSongProgress.find_by(youtubeurl:, clip_language:, translation_language:)            
      create_course if progress.ready?
    end

    def create_course
      progress = CreateSongProgress.find_or_create_by(youtubeurl:, clip_language:, translation_language:)      
      raise "Missing creation data" unless progress.ready?
      data = progress.data

      l1 = Language.find_by(english_name: clip_language)
      l2 = Language.find_by(english_name: translation_language)
      medium = Medium.find_or_create_by!(url: youtubeurl)
      slug = song_name.parameterize
      c = Course.find_or_create_by!(slug: ) do |c|
        c.name = song_name
        c.main_media_url = youtubeurl
      end
      c.lessons.destroy_all
      Lesson.where("slug like \'#{slug}%\'").destroy_all
      medium.phrases.destroy_all

      data["lessons"].each_with_index do |lesson_data, lesson_index|
        l = Lesson.create!(
          medium: medium,
          slug: "#{slug}#{lesson_index}",
          course: c,
          order: lesson_index,
          name: lesson_data["title"])

        a1 = Activities::WatchVideoActivity.create!(lesson: l, order: 1)
        a2 = Activities::MatchPhrasesActivity.create!(lesson: l, order: 2)
        a3 = Activities::SortPhrasesActivity.create!(lesson: l, order: 3)
        a4 = Activities::LanguageAlignmentActivity.create!(lesson: l, order: 4)
        a5 = Activities::SpeakActivity.create!(lesson: l, order: 5)
        a6 = Activities::ListenActivity.create!(lesson: l, order: 6)

        phrases = lesson_data["phrases"].each_with_index do |phrase_data, phrase_index|
          p = Phrase.create!(
            text_l1: phrase_data["text_l1"],
            text_l2: phrase_data["text_l2"],
            timestamp: phrase_data["timestamp"],
            medium:,
            l1:,
            l2:,
          )

          # Attach phrase audio if available
          if phrase_data["phrase_audio_data"].present?
            attach_audio_to_record(p, phrase_data["phrase_audio_data"], "phrase_#{phrase_index}.wav")
          end

          [ a1, a2, a3, a4, a5, a6 ].each { |a| a.phrases << p }

          (phrase_data["translations"] || []).each do |token_translation_data|
            t = TokenTranslation.create!(
              phrase: p,
              l1_start_index: token_translation_data["l1_start_index"],
              l2_start_index: token_translation_data["l2_start_index"],
              l1_end_index: token_translation_data["l1_end_index"] + 1,
              l2_end_index: token_translation_data["l2_end_index"] + 1,
              similar_sound: token_translation_data["similar_sound"],
              translation: token_translation_data["translation"],
            )

            # Attach token translation audio if available
            if token_translation_data["audio_data"].present?
              attach_audio_to_record(t, token_translation_data["audio_data"], "token_#{phrase_index}_#{t.l1_start_index}.wav")
            end

            a6.token_translations << t if token_translation_data["listening_activity"] == 1
            a4.token_translations << t if token_translation_data["language_alignment_activity"] == 1
          end
          p
        end
      end
    end


    def save_progress(step, data = nil)
      progress = CreateSongProgress.find_or_create_by(youtubeurl:, clip_language:, translation_language:)
      progress.data = data unless data.nil?
      progress.step = step
      progress.save!
    end

    def create_phrases
      json_schema = {
        type: "array",
        items: {
          type: "object",
          properties: {
            "text_l1": { type: "string", description: "phrase text in #{clip_language}" },
            "text_l2": { type: "string", description: "phrase translation in #{translation_language}" },
            "timestamp": { type: "string", description: "timestamp of the text in the clip (format: mm:ss)" }
          },
          required: ["text_l1", "text_l2", "timestamp"],
          additionalProperties: false
        },
      }
      lyrics = LyricsScraperService.call(lyrics_url)
      parser = Langchain::OutputParsers::StructuredOutputParser.from_json_schema(json_schema)
      prompt = Langchain::Prompt::PromptTemplate.new(
        template: File.read("prompts/extract_phrases_from_youtube_url.md"),
        input_variables: ["clip_language", "translation_language", "song_name", "format_instructions", "song_lyrics"])
      prompt_text = prompt.format(
        clip_language: clip_language,
        translation_language: translation_language,
        song_name: song_name,
        song_lyrics: lyrics,
        format_instructions: parser.get_format_instructions)

      llm_response = @gemini.chat(messages: [
        {role: "user", parts: [{text: File.read("prompts/system.md")}]},
        {role: "user", parts: [
          {text: prompt_text},
          {file_data: {file_uri: youtubeurl}},
        ]}
      ]).chat_completion
      pp llm_response
      structured_response = parser.parse(llm_response)
      pp structured_response

      phrases = structured_response.map {|phrase_data| Phrase.new(phrase_data) }
      save_progress(:create_phrases, CreateSongData.new(phrases: phrases, lessons: []))
    end

    def create_lessons
      # Load existing phrases from saved progress
      progress = CreateSongProgress.find_by(youtubeurl:, clip_language:, translation_language:)
      return unless progress&.data["phrases"]

      phrases = progress.data["phrases"]

      json_schema = {
        type: "array",
        items: {
          type: "object",
          properties: {
            "title": { type: "string", description: "A descriptive title for the lesson (e.g., 'Verse 1', 'Chorus', 'Bridge')" },
            "description": { type: "string", description: "A brief description of what this lesson covers" },
            "phrases": {
              type: "array",
              items: {
                type: "object",
                properties: {
                  "index": { type: "integer", description: "Index of the phrase from the input list" },
                  "text_l1": { type: "string", description: "The phrase text in #{clip_language}" },
                  "text_l2": { type: "string", description: "The phrase translation in #{translation_language}" },
                  "timestamp": { type: "string", description: "The phrase timestamp (format: mm:ss)" }
                },
                required: ["index", "text_l1", "text_l2", "timestamp"],
                additionalProperties: false
              },
              description: "Array of phrases that belong to this lesson, including their content for verification"
            }
          },
          required: ["title", "description", "phrases"],
          additionalProperties: false
        }
      }

      parser = Langchain::OutputParsers::StructuredOutputParser.from_json_schema(json_schema)
      prompt = Langchain::Prompt::PromptTemplate.new(
        template: File.read("prompts/create_lessons_from_phrases.md"),
        input_variables: ["clip_language", "translation_language", "song_name", "phrases_json", "format_instructions"]
      )

      # Convert phrases to a JSON representation for the prompt
      phrases_json = phrases.map.with_index do |phrase, index|
        {
          index: index,
          text_l1: phrase["text_l1"],
          text_l2: phrase["text_l2"],
          timestamp: phrase["timestamp"]
        }
      end.to_json

      prompt_text = prompt.format(
        clip_language: clip_language,
        translation_language: translation_language,
        song_name: song_name,
        phrases_json: phrases_json,
        format_instructions: parser.get_format_instructions
      )

      llm_response = @flash.chat(messages: [
        {role: "user", parts: [{text: File.read("prompts/system.md")}]},
        {role: "user", parts: [{text: prompt_text}]}
      ]).chat_completion

      pp llm_response
      structured_response = parser.parse(llm_response)
      pp structured_response

      # Validate that the LLM returned correct phrase information
      validate_lesson_phrases(structured_response, phrases)

      # Create lesson objects with calculated end timestamps
      lessons = structured_response.map do |lesson_data|
        calculated_end_timestamp = calculate_end_timestamp(lesson_data["phrases"], phrases)
        
        LessonData.new(
          title: lesson_data["title"],
          description: lesson_data["description"],
          start_timestamp: lesson_data["start_timestamp"],
          end_timestamp: calculated_end_timestamp,
          phrases: lesson_data["phrases"]
        )
      end

      # Update progress with lessons
      current_data = progress.data
      updated_data = CreateSongData.new(phrases: nil, lessons: lessons)
      save_progress(:create_lessons, updated_data)

      lessons
    end

    def create_token_translations
      progress = CreateSongProgress.find_by(clip_language:, youtubeurl:, translation_language:)
      data = progress.data
      
      # JSON schema for the LLM response
      json_schema = {
        type: "array",
        items: {
          type: "object",
          properties: {
            "translation_indices": { 
              type: "array", 
              items: { type: "integer" },
              description: "Continous token indices in the translation sentence"
            },
            "clip_indices": { 
              type: "array", 
              items: { type: "integer" },
              description: "Continous token indices in the clip sentence"
            },
            "translation_tokens": { 
              type: "array", 
              items: { type: "string" },
              description: "The actual tokens from the translation"
            },
            "clip_tokens": { 
              type: "array", 
              items: { type: "string" },
              description: "The actual tokens from the clip"
            }
          },
          required: ["translation_indices", "clip_indices", "translation_tokens", "clip_tokens"],
          additionalProperties: false
        }
      }
      
      parser = Langchain::OutputParsers::StructuredOutputParser.from_json_schema(json_schema)
      prompt = Langchain::Prompt::PromptTemplate.new(
        template: File.read("prompts/create_token_translations.md"),
        input_variables: ["clip_language", "translation_language", "phrase_text", "translation_text", "clip_tokens", "translation_tokens", "format_instructions"]
      )
      
      # Find the first phrase without translations and process from there
      data["lessons"].each_with_index do |lesson, lesson_index|
        lesson["phrases"].each_with_index do |phrase, phrase_index|
          next if phrase.key?("translations")
          
          # Tokenize the phrases
          clip_tokens = tokenize_text(phrase["text_l1"])
          translation_tokens = tokenize_text(phrase["text_l2"])
          
          prompt_text = prompt.format(
            clip_language: clip_language,
            translation_language: translation_language,
            phrase_text: phrase["text_l1"],
            translation_text: phrase["text_l2"],
            clip_tokens: clip_tokens.to_json,
            translation_tokens: translation_tokens.to_json,
            format_instructions: parser.get_format_instructions
          )
          
          llm_response = @openai.chat(messages: [
            {role: "user", content: File.read("prompts/system.md")},
            {role: "user", content: prompt_text}
          ]).chat_completion
          
          structured_response = parser.parse(llm_response)
          pp structured_response
          # Convert token indices to character indices
          translations = structured_response.map do |alignment|
            
            # Handle cases where alignment spans multiple tokens
            l1_start = find_character_index(phrase["text_l1"], clip_tokens, alignment["clip_indices"].first, alignment["clip_tokens"].first)
            l1_end = if alignment["clip_indices"].length > 1
              find_character_end_index(phrase["text_l1"], clip_tokens, alignment["clip_indices"].last, alignment["clip_tokens"].last)
            else
              find_character_end_index(phrase["text_l1"], clip_tokens, alignment["clip_indices"].first, alignment["clip_tokens"].first)
            end
            
            l2_start = find_character_index(phrase["text_l2"], translation_tokens, alignment["translation_indices"].first, alignment["translation_tokens"].first)
            l2_end = if alignment["translation_indices"].length > 1
              find_character_end_index(phrase["text_l2"], translation_tokens, alignment["translation_indices"].last, alignment["translation_tokens"].last)
            else
              find_character_end_index(phrase["text_l2"], translation_tokens, alignment["translation_indices"].first, alignment["translation_tokens"].first)
            end
            pp alignment
            {
              "l1_start_index" => l1_start,
              "l1_end_index" => l1_end,
              "l2_start_index" => l2_start,
              "l2_end_index" => l2_end,
              "translation" => alignment["translation_tokens"].join(" ")
            }
          end
          
          # Update the phrase with translations
          data["lessons"][lesson_index]["phrases"][phrase_index]["translations"] = translations
          
          # Save progress after each phrase
          save_progress(progress.step, data)
          
          puts "Processed phrase #{phrase_index} in lesson #{lesson_index}: #{phrase['text_l1']}"
        end
      end
      save_progress(:create_token_translations)
    end

    def create_listening_activities
      progress = CreateSongProgress.find_by(clip_language:, youtubeurl:, translation_language:)
      data = progress.data
      
      # JSON schema for the LLM response - expects the same structure as input but with modified translations
      json_schema = {
        type: "array",
        items: {
          type: "object",
          properties: {
            "text_l1": { type: "string" },
            "text_l2": { type: "string" },
            "timestamp": { type: "string" },
            "translations": {
              type: "array",
              items: {
                type: "object",
                properties: {
                  "l1_start_index": { type: "integer" },
                  "l1_end_index": { type: "integer" },
                  "l2_start_index": { type: "integer" },
                  "l2_end_index": { type: "integer" },
                  "translation": { type: "string" },
                  "listening_activity": { type: "integer" },
                  "similar_sound": {
                    type: "array",
                    items: { type: "string" }
                  }
                },
                required: ["l1_start_index", "l1_end_index", "l2_start_index", "l2_end_index", "translation"],
                additionalProperties: true
              }
            }
          },
          required: ["text_l1", "text_l2", "timestamp", "translations"],
          additionalProperties: true
        }
      }
      
      parser = Langchain::OutputParsers::StructuredOutputParser.from_json_schema(json_schema)
      prompt = Langchain::Prompt::PromptTemplate.new(
        template: File.read("prompts/create_listening_activities.md"),
        input_variables: ["clip_language", "translation_language", "input_json", "format_instructions"]
      )
      
      # Process each lesson that doesn't have listening activities yet
      data["lessons"].each_with_index do |lesson, lesson_index|
        # Check if this lesson already has listening activities
        has_listening_activities = lesson["phrases"].any? do |phrase|
          phrase["translations"]&.any? { |translation| translation.key?("listening_activity") }
        end
        
        # Skip if this lesson already has listening activities
        next if has_listening_activities
        
        # Prepare the input JSON for the LLM
        input_json = lesson["phrases"].to_json
        
        # Format the prompt using Langchain template syntax
        prompt_text = prompt.format(
          clip_language: clip_language,
          translation_language: translation_language,
          input_json: input_json,
          format_instructions: parser.get_format_instructions
        )
        
        # Call the LLM
        llm_response = @flash.chat(messages: [
          {role: "user", parts: [{text: File.read("prompts/system.md")}]},
          {role: "user", parts: [{text: prompt_text}]}
        ]).chat_completion
        
        # Parse the structured response
        begin
          structured_response = parser.parse(llm_response)
          
          # Update the lesson data with the modified phrases
          data["lessons"][lesson_index]["phrases"] = structured_response
          
          # Save progress after each lesson
          save_progress(progress.step, data)
          
          puts "Processed lesson #{lesson_index}: #{lesson['title'] || 'Untitled'}"
        rescue JSON::ParserError => e
          puts "Error parsing LLM response for lesson #{lesson_index}: #{e.message}"
          puts "LLM Response: #{llm_response}"
          next
        end
      end
      save_progress(:create_listening_activities)
    end

    def create_language_alignment_activities
      progress = CreateSongProgress.find_by(clip_language:, youtubeurl:, translation_language:)
      data = progress.data
      
      # JSON schema for the LLM response - expects the same structure as input but with modified translations
      json_schema = {
        type: "array",
        items: {
          type: "object",
          properties: {
            "text_l1": { type: "string" },
            "text_l2": { type: "string" },
            "timestamp": { type: "string" },
            "translations": {
              type: "array",
              items: {
                type: "object",
                properties: {
                  "l1_start_index": { type: "integer" },
                  "l1_end_index": { type: "integer" },
                  "l2_start_index": { type: "integer" },
                  "l2_end_index": { type: "integer" },
                  "translation": { type: "string" },
                  "language_alignment_activity": { type: "integer" },
                },
                required: ["l1_start_index", "l1_end_index", "l2_start_index", "l2_end_index", "translation"],
                additionalProperties: true
              }
            }
          },
          required: ["text_l1", "text_l2", "timestamp", "translations"],
          additionalProperties: true
        }
      }
      
      parser = Langchain::OutputParsers::StructuredOutputParser.from_json_schema(json_schema)
      prompt = Langchain::Prompt::PromptTemplate.new(
        template: File.read("prompts/create_language_alignment_activities.md"),
        input_variables: ["clip_language", "translation_language", "input_json", "format_instructions"]
      )
      
      # Process each lesson that doesn't have language alignment activities yet
      data["lessons"].each_with_index do |lesson, lesson_index|
        # Check if this lesson already has language alignment activities
        has_language_alignment_activities = lesson["phrases"].any? do |phrase|
          phrase["translations"]&.any? { |translation| translation.key?("language_alignment_activity") }
        end
        
        # Skip if this lesson already has language alignment activities
        next if has_language_alignment_activities
        
        # Prepare the input JSON for the LLM
        input_json = lesson["phrases"].to_json
        
        # Format the prompt using Langchain template syntax
        prompt_text = prompt.format(
          clip_language: clip_language,
          translation_language: translation_language,
          input_json: input_json,
          format_instructions: parser.get_format_instructions
        )
        
        # Call the LLM
        llm_response = @flash.chat(messages: [
          {role: "user", parts: [{text: File.read("prompts/system.md")}]},
          {role: "user", parts: [{text: prompt_text}]}
        ]).chat_completion
        
        # Parse the structured response
        begin
          structured_response = parser.parse(llm_response)
          
          # Update the lesson data with the modified phrases
          data["lessons"][lesson_index]["phrases"] = structured_response
          
          # Save progress after each lesson
          save_progress(progress.step, data)
          
          puts "Processed lesson #{lesson_index}: #{lesson['title'] || 'Untitled'}"
        rescue JSON::ParserError => e
          puts "Error parsing LLM response for lesson #{lesson_index}: #{e.message}"
          puts "LLM Response: #{llm_response}"
          next
        end
      end
      save_progress(:create_language_alignment_activities)
    end

    def create_audio
      progress = CreateSongProgress.find_by(clip_language:, youtubeurl:, translation_language:)
      data = progress.data
      
      # Get language code mapping for the clip language
      language_code = get_language_code(clip_language)
      
      # Process each lesson
      data["lessons"].each_with_index do |lesson, lesson_index|
        lesson["phrases"].each_with_index do |phrase, phrase_index|
          # Generate audio for the full phrase text_l1 if not already done
          if !phrase.key?("phrase_audio_data")
            begin
              phrase_audio_data = generate_tts_audio(phrase["text_l1"], language_code)
              
              # Save the audio data for the phrase
              data["lessons"][lesson_index]["phrases"][phrase_index]["phrase_audio_data"] = phrase_audio_data
              
              # Save progress after each phrase to avoid losing work
              save_progress(progress.step, data)
              
              puts "Generated audio for phrase '#{phrase["text_l1"]}' in lesson #{lesson_index}, phrase #{phrase_index}"
            rescue => e
              puts "Error generating audio for phrase '#{phrase["text_l1"]}': #{e.message}"
              # Continue with next phrase instead of failing completely
            end
          end
          
          next unless phrase["translations"]
          
          phrase["translations"].each_with_index do |translation, translation_index|
            # Skip if this translation already has audio
            next if translation.key?("audio_data")
            
            # Extract the L1 text for this translation
            l1_text = phrase["text_l1"]
            l1_start = translation["l1_start_index"]
            l1_end = translation["l1_end_index"]
            token_text = l1_text[l1_start..l1_end]
            
            # Generate audio for this token
            begin
              audio_data = generate_tts_audio(token_text, language_code)
              
              # Save the audio data in the translation
              data["lessons"][lesson_index]["phrases"][phrase_index]["translations"][translation_index]["audio_data"] = audio_data
              
              # Save progress after each token to avoid losing work
              save_progress(progress.step, data)
              
              puts "Generated audio for token '#{token_text}' in lesson #{lesson_index}, phrase #{phrase_index}"
            rescue => e
              puts "Error generating audio for token '#{token_text}': #{e.message}"
              # Continue with next token instead of failing completely
            end
          end
        end
      end
      
      save_progress(:create_audio)
    end
  
    def generate_tts_audio(text, language_code)
      AzureTextToSpeechService.synthesize(text:, lang: language_code)
    end

    def get_language_code(language_name)
      # Find language by english_name and return iso_name
      language = Language.find_by(english_name: language_name)
      language.iso_name
    end

    def validate_lesson_phrases(lessons, original_phrases)
      lessons.each_with_index do |lesson, lesson_index|
        lesson["phrases"].each do |phrase_data|
          index = phrase_data["index"]
          original_phrase = original_phrases[index]
          
          unless original_phrase
            puts "Warning: Lesson #{lesson_index + 1} references phrase index #{index} which doesn't exist"
            next
          end
          
          # Validate that the phrase content matches
          if original_phrase["text_l1"] != phrase_data["text_l1"]
            puts "Warning: Lesson #{lesson_index + 1} phrase #{index} text_l1 mismatch:"
            puts "  Expected: #{original_phrase['text_l1']}"
            puts "  Got: #{phrase_data["text_l1"]}"
          end
          
          if original_phrase['text_l2'] != phrase_data["text_l2"]
            puts "Warning: Lesson #{lesson_index + 1} phrase #{index} text_l2 mismatch:"
            puts "  Expected: #{original_phrase['text_l2']}"
            puts "  Got: #{phrase_data["text_l2"]}"
          end
          
          if original_phrase["timestamp"] != phrase_data["timestamp"]
            puts "Warning: Lesson #{lesson_index + 1} phrase #{index} timestamp mismatch:"
            puts "  Expected: #{original_phrase['timestamp']}"
            puts "  Got: #{phrase_data["timestamp"]}"
          end
        end
      end
    end

    def timestamp_to_seconds(timestamp)
      parts = timestamp.split(':')
      minutes = parts[0].to_i
      seconds = parts[1].to_i
      minutes * 60 + seconds
    end

    def seconds_to_timestamp(seconds)
      minutes = seconds / 60
      remaining_seconds = seconds % 60
      "#{minutes}:#{'%02d' % remaining_seconds}"
    end

    def calculate_end_timestamp(lesson_phrases, all_phrases)
      # Find the highest index in this lesson
      last_phrase_index = lesson_phrases.map { |p| p["index"] }.max
      
      # Find the next phrase after this lesson
      next_phrase_index = last_phrase_index + 1
      
      if next_phrase_index < all_phrases.length
        # If there's a next phrase, end timestamp is that phrase's timestamp
        all_phrases[next_phrase_index]["timestamp"]
      else
        # If this is the last phrase, add 10 seconds to its timestamp
        last_phrase_timestamp = lesson_phrases.find { |p| p["index"] == last_phrase_index }["timestamp"]
        last_phrase_seconds = timestamp_to_seconds(last_phrase_timestamp)
        seconds_to_timestamp(last_phrase_seconds + 10)
      end
    end

    private

    # Helper method to attach base64 encoded audio data to a record using Active Storage
    def attach_audio_to_record(record, base64_audio_data, filename)
      return unless base64_audio_data.present?

      begin
        # Decode base64 audio data
        decoded_audio = Base64.decode64(base64_audio_data)
        
        # Create StringIO object from decoded data
        audio_io = StringIO.new(decoded_audio)
        audio_io.set_encoding_by_bom
        
        # Attach to the record's l1_audio using Active Storage
        record.l1_audio.attach(
          io: audio_io,
          filename: filename,
          content_type: 'audio/wav',
        )
        
        puts "Successfully attached audio to #{record.class.name} (#{filename})"
      rescue => e
        puts "Error attaching audio to #{record.class.name}: #{e.message}"
        # Continue processing other records even if one fails
      end
    end

    def tokenize_text(text)
      # Simple tokenization - split by spaces and punctuation
      # This can be enhanced with more sophisticated tokenization if needed
      text.split(/\P{L}/u).reject(&:empty?)
    end

    def map_tokens_with_positions(text)
      # Map each token to its character position in the original text
      positions = []
      text.scan(/\p{L}+/u) do |word|
        positions << {
          token: word,
          start_index: Regexp.last_match.begin(0),
          end_index: Regexp.last_match.end(0) - 1
        }
      end
      positions
    end

    def find_character_index(text, tokens, token_index, expected_token)
      # Get the token positions for the text
      token_positions = map_tokens_with_positions(text)
      
      # Validate that we have enough tokens
      return 0 if token_index >= token_positions.length
      
      # Validate that the token at the given index matches the expected token
      if token_positions[token_index][:token] != expected_token
        puts "Warning: Token mismatch at index #{token_index}. Expected '#{expected_token}', got '#{token_positions[token_index][:token]}'"
        # Fallback: try to find the token by searching
        matching_position = token_positions.find { |pos| pos[:token] == expected_token }
        return matching_position ? matching_position[:start_index] : 0
      end
      
      token_positions[token_index][:start_index]
    end

    def find_character_end_index(text, tokens, token_index, expected_token)
      # Get the token positions for the text
      token_positions = map_tokens_with_positions(text)
      
      # Validate that we have enough tokens
      return 0 if token_index >= token_positions.length
      
      # Validate that the token at the given index matches the expected token
      if token_positions[token_index][:token] != expected_token
        puts "Warning: Token mismatch at index #{token_index}. Expected '#{expected_token}', got '#{token_positions[token_index][:token]}'"
        # Fallback: try to find the token by searching
        matching_position = token_positions.find { |pos| pos[:token] == expected_token }
        return matching_position ? matching_position[:end_index] : 0
      end
      
      token_positions[token_index][:end_index]
    end


  end
end
