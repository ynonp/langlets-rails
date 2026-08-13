module CreateSong
  module Pipeline
    extend ActiveSupport::Concern

    class_methods do
      def detect_language(url:)
        languages = Language.order(:id).pluck(:iso_name, :english_name).map do |iso_name, english_name|
          { iso_name:, english_name: }
        end
        response = PipelineClient.detect_language(
          youtubeurl: url,
          supported_languages: languages
        )
        language = Language.find_by!(iso_name: response.dig("language", "iso_name"))
        [ language, response["data"].presence || {} ]
      rescue ActiveRecord::RecordNotFound => error
        raise PipelineClient::Error, "language detection returned an unreadable language: #{error.message}"
      end

      def run_pipeline(youtube_url:, clip_language:, translation_language:, wait: false)
        language = Language.find_by(english_name: translation_language) ||
          Language.find_by(iso_name: translation_language)
        raise ArgumentError, "unknown translation language: #{translation_language}" unless language

        progress = find_or_create_pipeline_progress(resolve_pipeline_url(youtube_url), clip_language)
        progress.run_pipeline(language:, wait:)
        progress
      end

      private

      def resolve_pipeline_url(url)
        return VideoSource.canonical(url) if VideoSource.video_id(url).present?
        return url if VideoSource.provider(url).nil?

        VideoSource.fetch(url).canonical_url
      rescue VideoSource::UnavailableVideo => error
        raise ArgumentError, "could not resolve #{url.inspect}: #{error.message}"
      end

      def find_or_create_pipeline_progress(url, clip_language)
        progress = find_or_create_by!(youtubeurl: url, clip_language:) do |record|
          record.data = {}
        end
        progress.update!(data: {}) if progress.data.nil?
        progress
      end
    end

    def run_pipeline(language: nil, wait: false)
      raise ArgumentError, "CreateSongProgress must be persisted" unless persisted?

      response = PipelineClient.run(pipeline_payload(language), wait:)
      raise PipelineClient::Error, "pipeline run failed: #{response['failed'].to_json}" if wait && !response["ok"]

      wait ? reload : true
    end

    private

    def pipeline_payload(language)
      {
        youtubeurl:,
        clip_language:,
        translation_language: pipeline_language_ref(language),
        callback_url: "#{pipeline_callback_url}/pipeline_callbacks/#{id}",
        data: data || {}
      }
    end

    def pipeline_callback_url
      Rails.configuration.x.pipeline.callback_base_url.delete_suffix("/")
    end

    def pipeline_language_ref(language)
      return nil if language.nil?

      { id: language.id, iso_name: language.iso_name, english_name: language.english_name }
    end
  end
end
