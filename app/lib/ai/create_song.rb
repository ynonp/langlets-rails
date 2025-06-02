module Ai
  class CreateSong
    attr_accessor :youtubeurl, :clip_language, :translation_language, :data, :gemini, :openai, :claude, :song_name

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

    def initialize(song_name, youtubeurl, clip_language, translation_language)
      @song_name = song_name
      @clip_language = clip_language
      @translation_language = translation_language
      @youtubeurl = youtubeurl
      @gemini = Langchain::LLM::GoogleGemini.new(
        api_key: Rails.application.credentials.google_api_key,
        default_options: { chat_model: 'gemini-2.5-pro-preview-05-06' },
      )
      @gemini.read_timeout = 600
      @flash = Langchain::LLM::GoogleGemini.new(
        api_key: Rails.application.credentials.google_api_key,
        default_options: { chat_model: 'gemini-2.5-flash-preview-05-20' },
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

    def save_progress(step, data)
      progress = CreateSongProgress.find_or_create_by(youtubeurl:, clip_language:, translation_language:)
      progress.data = data
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
      parser = Langchain::OutputParsers::StructuredOutputParser.from_json_schema(json_schema)
      prompt = Langchain::Prompt::PromptTemplate.new(
        template: File.read("prompts/extract_phrases_from_youtube_url.md"),
        input_variables: ["clip_language", "translation_language", "song_name", "format_instructions"])
      prompt_text = prompt.format(
        clip_language: clip_language,
        translation_language: translation_language,
        song_name: song_name,
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

    def create_lesson_models(medium)
      # Load existing lesson data from saved progress
      progress = CreateSongProgress.find_by(youtubeurl:, clip_language:, translation_language:)
      return unless progress&.data&.lessons

      lesson_data_objects = progress.data.lessons
      
      lesson_data_objects.map do |lesson_data|
        Lesson.create!(
          medium: medium,
          title: lesson_data.title,
          description: lesson_data.description,
          start_timestamp: lesson_data.start_timestamp,
          end_timestamp: lesson_data.end_timestamp
        )
      end
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
          
          llm_response = @flash.chat(messages: [
            {role: "user", parts: [{text: File.read("prompts/system.md")}]},
            {role: "user", parts: [{text: prompt_text}]}
          ]).chat_completion
          
          structured_response = parser.parse(llm_response)
          
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
          save_progress(:create_token_translations, data)
          
          puts "Processed phrase #{phrase_index} in lesson #{lesson_index}: #{phrase['text_l1']}"
        end
      end
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
          save_progress(:create_listening_activities, data)
          
          puts "Processed lesson #{lesson_index}: #{lesson['title'] || 'Untitled'}"
        rescue JSON::ParserError => e
          puts "Error parsing LLM response for lesson #{lesson_index}: #{e.message}"
          puts "LLM Response: #{llm_response}"
          next
        end
      end
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
          save_progress(:create_language_alignment_activities, data)
          
          puts "Processed lesson #{lesson_index}: #{lesson['title'] || 'Untitled'}"
        rescue JSON::ParserError => e
          puts "Error parsing LLM response for lesson #{lesson_index}: #{e.message}"
          puts "LLM Response: #{llm_response}"
          next
        end
      end
    end
    
    def write_script
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

    def tokenize_text(text)
      # Simple tokenization - split by spaces and punctuation
      # This can be enhanced with more sophisticated tokenization if needed
      text.split(/\P{L}/u).reject(&:empty?)
    end

    def find_character_index(text, tokens, token_index, expected_token)
      # Count how many times this token appears before the target index
      occurrence_count = 0
      tokens[0...token_index].each do |token|
        occurrence_count += 1 if token == expected_token
      end
      
      # Find the nth occurrence of the token in the text
      current_pos = 0
      (occurrence_count + 1).times do
        token_pos = text.index(expected_token, current_pos)
        return 0 unless token_pos # Token not found, return 0 as fallback
        
        if occurrence_count == 0
          return token_pos # This is the occurrence we want
        else
          current_pos = token_pos + expected_token.length
          occurrence_count -= 1
        end
      end
      
      # Fallback if not found
      text.index(expected_token) || 0
    end

    def find_character_end_index(text, tokens, token_index, expected_token)
      start_index = find_character_index(text, tokens, token_index, expected_token)
      start_index + expected_token.length - 1
    end
  end
end
