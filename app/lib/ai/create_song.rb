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
      full_lyrics = data["lessons"].flat_map {|l| l["phrases"].map { |p| p["text_l1"] } }.join("\n")
      
      # find the first phrase without translations
      # iterate from that phrase
      #   use LLM to create token translations
      #   conver LLM response to TokenTranslation (character) indexes
      #   update `data` in CreateSongProgress
      print full_lyrics
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
  end
end
