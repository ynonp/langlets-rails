module Ai
  class CreateSong
    attr_accessor :youtubeurl, :clip_language, :translation_language, :data, :gemini, :openai, :claude, :song_name

    CreateSongData = Data.define(
      :phrases,
      :lessons,
      :lyrics,
    )

    LessonData = Data.define(
      :title,
      :description,
      :start_timestamp,
      :end_timestamp,
      :phrases
    )

    def with_retry(max_attempts: 3, delay: 1)
      attempts = 0
      begin
        attempts += 1
        yield
      rescue StandardError => e
        if attempts < max_attempts
          puts "Attempt #{attempts} failed: #{e.message}. Retrying in #{delay} seconds..."
          sleep(delay)
          delay *= 2  # Exponential backoff
          retry
        else
          puts "All #{max_attempts} attempts failed. Giving up."
          raise e
        end
      end
    end

    def initialize(song_name, youtubeurl, clip_language, translation_language)
      @song_name = song_name
      @clip_language = clip_language
      @translation_language = translation_language
      @youtubeurl = youtubeurl
      init_ai_agents unless Rails.env.test?
    end

    def init_ai_agents
      @gemini = Langchain::LLM::GoogleGemini.new(
        api_key: Rails.application.credentials.google_api_key,
        default_options: { temperature: 0.6, chat_model: 'gemini-2.5-pro-preview-06-05' },
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
      with_retry(max_attempts: 5, delay: 10) do
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
      progress = CreateSongProgress.find_by(youtubeurl:, clip_language:, translation_language:)
      current_data = progress.data

      lyrics = current_data&.dig(:lyrics).presence || "Reference Lyrics Not Available - Pay extra attention listening"

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

      Rails.logger.info("Create song create_phrases prompt: #{prompt_text}")
      llm_response = @gemini.chat(messages: [
        {role: "user", parts: [{text: File.read("prompts/system.md")}]},
        {role: "user", parts: [
          {text: prompt_text},
          {file_data: {file_uri: youtubeurl}},
        ]}
      ]).chat_completion
      Rails.logger.info(llm_response)
      structured_response = parser.parse(llm_response)

      phrases = structured_response.map {|phrase_data| Phrase.new(phrase_data) }
      save_progress(:create_phrases, CreateSongData.new(lyrics: current_data&.dig(:lyrics), phrases:, lessons: []))
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

      Rails.logger.info(llm_response)
      structured_response = parser.parse(llm_response)
      Rails.logger.info(structured_response)

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
      current_data = progress.reload.data
      updated_data = CreateSongData.new(lyrics: current_data&.dig(:lyrics), phrases: nil, lessons: lessons)
      save_progress(:create_lessons, updated_data)

      lessons
    end

    def create_token_translations
      progress = CreateSongProgress.find_by(clip_language:, youtubeurl:, translation_language:)
      data = progress.data
      
      # JSON schema for the LLM response - now expecting batch results
      json_schema = {
        type: "object",
        properties: {
          "phrases": {
            type: "array",
            items: {
              type: "object",
              properties: {
                "phrase_id": { type: "string", description: "Unique identifier for the phrase" },
                "clip_text": { type: "string", description: "Original clip text for verification" },
                "translation_text": { type: "string", description: "Translation text for verification" },
                "translations": {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      "translation_indices": { 
                        type: "array", 
                        items: { type: "integer" },
                        description: "Continuous token indices in the translation sentence"
                      },
                      "clip_indices": { 
                        type: "array", 
                        items: { type: "integer" },
                        description: "Continuous token indices in the clip sentence"
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
              },
              required: ["phrase_id", "clip_text", "translation_text", "translations"],
              additionalProperties: false
            }
          }
        },
        required: ["phrases"],
        additionalProperties: false
      }
      
      parser = Langchain::OutputParsers::StructuredOutputParser.from_json_schema(json_schema)
      prompt = Langchain::Prompt::PromptTemplate.new(
        template: File.read("prompts/create_token_translations_batch.md"),
        input_variables: ["clip_language", "translation_language", "phrases_json", "format_instructions"]
      )
      
      # Collect all phrases that need translations
      phrases_to_process = []
      phrase_lookup = {}
      
      data["lessons"].each_with_index do |lesson, lesson_index|
        lesson["phrases"].each_with_index do |phrase, phrase_index|
          next if phrase.key?("translations")
          
          phrase_id = "lesson_#{lesson_index}_phrase_#{phrase_index}"
          
          # Tokenize the phrases
          clip_tokens = tokenize_text(phrase["text_l1"])
          translation_tokens = tokenize_text(phrase["text_l2"])
          
          phrase_data = {
            phrase_id: phrase_id,
            clip_text: phrase["text_l1"],
            translation_text: phrase["text_l2"],
            clip_tokens: clip_tokens,
            translation_tokens: translation_tokens
          }
          
          phrases_to_process << phrase_data
          phrase_lookup[phrase_id] = { lesson_index: lesson_index, phrase_index: phrase_index }
        end
      end
      
      # Return early if no phrases need processing
      return if phrases_to_process.empty?
      
      # Create structured JSON input for the LLM
      phrases_json = {
        phrases: phrases_to_process
      }.to_json
      
      prompt_text = prompt.format(
        clip_language: clip_language,
        translation_language: translation_language,
        phrases_json: phrases_json,
        format_instructions: parser.get_format_instructions
      )
      
      Rails.logger.info("Batch processing #{phrases_to_process.length} phrases for token translations")
      
      llm_response = @openai.chat(messages: [
        {role: "user", content: prompt_text}
      ]).chat_completion

      structured_response = parser.parse(llm_response)
      Rails.logger.info("Received batch response with #{structured_response['phrases'].length} phrases")
      
      # Process each phrase result
      structured_response["phrases"].each do |phrase_result|
        phrase_id = phrase_result["phrase_id"]
        lookup = phrase_lookup[phrase_id]
        
        unless lookup
          Rails.logger.warn("Received result for unknown phrase_id: #{phrase_id}")
          next
        end
        
        lesson_index = lookup[:lesson_index]
        phrase_index = lookup[:phrase_index]
        phrase = data["lessons"][lesson_index]["phrases"][phrase_index]
        
        # Verify the phrase texts match
        unless phrase["text_l1"] == phrase_result["clip_text"] && phrase["text_l2"] == phrase_result["translation_text"]
          Rails.logger.warn("Text mismatch for phrase_id #{phrase_id}")
          next
        end
        
        # Convert token indices to character indices
        translations = phrase_result["translations"].filter_map do |alignment|
          clip_tokens = tokenize_text(phrase["text_l1"])
          translation_tokens = tokenize_text(phrase["text_l2"])
          Rails.logger.debug("clip tokens: #{clip_tokens}; translation_tokens: #{translation_tokens}")
          
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
          
          # Validate that start indices are smaller than end indices
          if l1_start > l1_end
            Rails.logger.error("Invalid L1 indices for phrase_id #{phrase_id}: l1_start=#{l1_start} >= l1_end=#{l1_end}. Skipping this token translation.")
            next
          end
          
          if l2_start > l2_end
            Rails.logger.error("Invalid L2 indices for phrase_id #{phrase_id}: l2_start=#{l2_start} >= l2_end=#{l2_end}. Skipping this token translation.")
            next
          end
          
          # Validate that indices are within text bounds
          if l1_start < 0 || l1_end >= phrase["text_l1"].length
            Rails.logger.error("L1 indices out of bounds for phrase_id #{phrase_id}: l1_start=#{l1_start}, l1_end=#{l1_end}, text_length=#{phrase["text_l1"].length}. Skipping this token translation.")
            next
          end
          
          if l2_start < 0 || l2_end >= phrase["text_l2"].length
            Rails.logger.error("L2 indices out of bounds for phrase_id #{phrase_id}: l2_start=#{l2_start}, l2_end=#{l2_end}, text_length=#{phrase["text_l2"].length}. Skipping this token translation.")
            next
          end
          
          translation_data = {
            "l1_start_index" => l1_start,
            "l1_end_index" => l1_end,
            "l2_start_index" => l2_start,
            "l2_end_index" => l2_end,
            "translation" => alignment["translation_tokens"].join(" ")
          }
          
          # Log the valid translation data for debugging
          Rails.logger.debug("Valid token translation for phrase_id #{phrase_id}: #{translation_data}")
          
          translation_data
        end
        
        # Update the phrase with translations
        data["lessons"][lesson_index]["phrases"][phrase_index]["translations"] = translations
        
        Rails.logger.info("Processed phrase #{phrase_index} in lesson #{lesson_index}: #{phrase['text_l1']}")
      end
      
      # Save progress once after processing all phrases
      save_progress(:create_token_translations, data)
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
      save_progress(:ready)
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
      Rails.logger.debug("text: #{text}, tokens: #{tokens}, index: #{token_index}, expected_token: #{expected_token}")
      # Get the token positions for the text
      token_positions = map_tokens_with_positions(text)
      
      # Check if expected_token is a multi-token phrase or contains special characters
      if expected_token.include?(' ') || expected_token.match?(/\p{P}/) || expected_token.match?(/\d/)
        Rails.logger.debug("Detected multi-token/complex expectation: #{expected_token}")
        
        # Strategy 1: Try to find the exact substring in the text
        substring_start = text.index(expected_token)
        if substring_start
          Rails.logger.debug("Found as substring: #{substring_start}")
          return substring_start
        end
        
        # Strategy 2: Try to find it by tokenizing the expected phrase and finding consecutive tokens
        expected_tokens = expected_token.split(/\s+/)
        Rails.logger.debug("Split into tokens: #{expected_tokens}")
        
        # Look for the sequence starting from the given token_index
        if token_index + expected_tokens.length <= token_positions.length
          match = true
          (0...expected_tokens.length).each do |i|
            actual_token = token_positions[token_index + i][:token]
            expected_subtoken = expected_tokens[i]
            if actual_token != expected_subtoken
              Rails.logger.debug("Mismatch at offset #{i}: expected '#{expected_subtoken}', got '#{actual_token}'")
              match = false
              break
            end
          end
          
          if match
            start_pos = token_positions[token_index][:start_index]
            Rails.logger.debug("Found token sequence: #{start_pos}")
            return start_pos
          end
        end
        
        # Strategy 3: Search for the token sequence anywhere in the text
        Rails.logger.debug("Searching for token sequence anywhere in text")
        (0..token_positions.length - expected_tokens.length).each do |start_idx|
          match = true
          (0...expected_tokens.length).each do |i|
            if token_positions[start_idx + i][:token] != expected_tokens[i]
              match = false
              break
            end
          end
          
          if match
            start_pos = token_positions[start_idx][:start_index]
            Rails.logger.debug("Found token sequence at different position: #{start_pos}")
            return start_pos
          end
        end
        
        Rails.logger.warn("Multi-token phrase not found: #{expected_token}")
        return 0
      else
        # Single token handling - existing logic
        # Validate that we have enough tokens
        return 0 if token_index >= token_positions.length
        
        # Validate that the token at the given index matches the expected token
        if token_positions[token_index][:token] != expected_token
          Rails.logger.warn("Token mismatch at index #{token_index}. Expected '#{expected_token}', got '#{token_positions[token_index][:token]}'")
          # Fallback: try to find the token by searching
          matching_position = token_positions.find { |pos| pos[:token] == expected_token }
          return matching_position ? matching_position[:start_index] : 0
        end
        
        token_positions[token_index][:start_index]
      end
    end

    def find_character_end_index(text, tokens, token_index, expected_token)
      Rails.logger.debug("find_character_end_index. text: #{text}, tokens: #{tokens}, index: #{token_index}, expected: #{expected_token}")
      # Get the token positions for the text
      token_positions = map_tokens_with_positions(text)
      
      # Check if expected_token is a multi-token phrase or contains special characters
      if expected_token.include?(' ') || expected_token.match?(/\p{P}/) || expected_token.match?(/\d/)
        Rails.logger.debug("Detected multi-token/complex expectation: #{expected_token}")
        
        # Strategy 1: Try to find the exact substring in the text
        substring_start = text.index(expected_token)
        if substring_start
          substring_end = substring_start + expected_token.length - 1
          Rails.logger.debug("Found as substring: #{substring_end}")
          return substring_end
        end
        
        # Strategy 2: Try to find it by tokenizing the expected phrase and finding consecutive tokens
        expected_tokens = expected_token.split(/\s+/)
        Rails.logger.debug("Split into tokens: #{expected_tokens}")
        
        # Look for the sequence starting from the given token_index
        if token_index + expected_tokens.length <= token_positions.length
          match = true
          (0...expected_tokens.length).each do |i|
            actual_token = token_positions[token_index + i][:token]
            expected_subtoken = expected_tokens[i]
            if actual_token != expected_subtoken
              Rails.logger.debug("Mismatch at offset #{i}: expected '#{expected_subtoken}', got '#{actual_token}'")
              match = false
              break
            end
          end
          
          if match
            end_pos = token_positions[token_index + expected_tokens.length - 1][:end_index]
            Rails.logger.debug("Found token sequence: #{end_pos}")
            return end_pos
          end
        end
        
        # Strategy 3: Search for the token sequence anywhere in the text
        Rails.logger.debug("Searching for token sequence anywhere in text")
        (0..token_positions.length - expected_tokens.length).each do |start_idx|
          match = true
          (0...expected_tokens.length).each do |i|
            if token_positions[start_idx + i][:token] != expected_tokens[i]
              match = false
              break
            end
          end
          
          if match
            end_pos = token_positions[start_idx + expected_tokens.length - 1][:end_index]
            Rails.logger.debug("Found token sequence at different position: #{end_pos}")
            return end_pos
          end
        end
        
        Rails.logger.warn("Multi-token phrase not found: #{expected_token}")
        return 0
      else
        # Single token handling - existing logic
        # Validate that we have enough tokens
        return 0 if token_index >= token_positions.length
        
        # Validate that the token at the given index matches the expected token
        if token_positions[token_index][:token] != expected_token
          Rails.logger.warn("Token mismatch at index #{token_index}. Expected '#{expected_token}', got '#{token_positions[token_index][:token]}'")
          # Fallback: try to find the token by searching
          matching_position = token_positions.find { |pos| pos[:token] == expected_token }
          return matching_position ? matching_position[:end_index] : 0
        end
        
        token_positions[token_index][:end_index]
      end
    end


  end
end
