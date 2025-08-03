module Llm
  # Represents YouTube URL content for LLM processing
  class YoutubeUrlContent < RubyLLM::Content
    attr_reader :youtube_url

    def initialize(youtube_url)
      @youtube_url = youtube_url
      # Don't call super since we don't want the validation that requires text or attachments
      @text = nil
      @attachments = []
    end

    # Define custom formatting behavior for this content type
    def format_content
      {
        "file_data": {
          "mime_type": "video/mp4",
          "file_uri": @youtube_url,
        }
      }
    end

    # For Rails serialization
    def to_h
      { youtube_url: @youtube_url }
    end
  end
end
