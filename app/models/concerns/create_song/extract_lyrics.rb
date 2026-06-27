module CreateSong
  module ExtractLyrics
    extend ActiveSupport::Concern

    MODEL_PARAMS = {
      model: 'gemini-3.5-flash',
      provider: :gemini,
      assume_model_exists: true
    }.freeze

    def full_lyrics
      data["phrases"].pluck("text_l1").join("\n")
    end

    # Transcribes the video into word-timed phrases. A single LLM call returns
    # JSON with line- and word-level timestamps (see WordTimingParser), which we
    # parse into data["phrases"], each carrying a "words" array. Every word also
    # gets its l1_start_index / l1_end_index (character span within text_l1)
    # computed here so downstream steps can build tokens without re-searching.
    def extract_lyrics
      user_content = Llm::YoutubeUrlContent.new(youtubeurl)

      instructions = ApplicationController.renderer.render(
        template: "prompts/extract_phrases_from_youtube_url",
        formats: [ :md ],
        locals: { clip_language: }
      )

      chat = TracedChat.new(span_name: "extract_lyrics", **MODEL_PARAMS)
      chat
        .with_instructions(instructions)
        .with_schema(LyricsTranscriptionSchema)
        # gemini-3.5-flash is a reasoning model and, left unbounded, spends its
        # entire ~64k output-token budget "thinking" -- the JSON then truncates
        # mid-line and fails to parse. Transcription is mechanical, so cap the
        # reasoning to thinkingLevel:low (≈800 thinking tokens vs ≈63k), which
        # leaves the budget for the actual output. (thinkingBudget is ignored by
        # the Gemini 3 family; only the effort/level control works here.)
        .with_thinking(effort: :low)
        .with_temperature(0.2)
        .add_message role: :user, content: user_content

      # With a schema, response.content is the parsed Hash ({ "lines" => [...] }).
      response = chat.complete
      phrases = WordTimingParser.parse(response.content)

      self.data ||= {}
      self.data["phrases"] = phrases

      save!
    end
  end
end
