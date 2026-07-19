require "tempfile"

class CreateSongPipelineCli
  DEFAULT_CALLBACK_BASE_URL = "http://localhost:3000"

  def initialize(youtube_url:, clip_language:, translation_language:, callback_base_url: nil, command_runner: nil)
    @youtube_url = youtube_url
    @clip_language = clip_language
    @translation_language_name = translation_language
    @callback_base_url = callback_base_url.presence || DEFAULT_CALLBACK_BASE_URL
    @command_runner = command_runner || method(:run_command)
  end

  def call
    secret = PipelineHmac.secret
    raise ArgumentError, "PIPELINE_HMAC_SECRET is not configured" if secret.blank?

    language = Language.find_by(english_name: @translation_language_name) ||
      Language.find_by(iso_name: @translation_language_name)
    raise ArgumentError, "unknown translation language: #{@translation_language_name}" unless language

    progress = find_or_create_progress(language)

    Tempfile.create([ "create-song-progress-#{progress.id}-", ".json" ]) do |file|
      progress.reload.export(file.path)
      callback_url = "#{@callback_base_url.delete_suffix('/')}/pipeline_callbacks/#{progress.id}"
      command = [
        "deno", "task", "cli", callback_url,
        "--input", file.path,
        "--iso", language.iso_name,
        "--lang-id", language.id.to_s
      ]

      success = @command_runner.call(
        { "PIPELINE_HMAC_SECRET" => secret },
        command,
        Rails.root.join("pipeline").to_s
      )
      raise "Deno pipeline failed for CreateSongProgress #{progress.id}" unless success
    end

    progress.reload
  end

  private

  def find_or_create_progress(language)
    progress = CreateSongProgress.find_or_create_by!(
      youtubeurl: @youtube_url,
      clip_language: @clip_language
    ) do |record|
      record.translation_language = language.english_name
      record.data = {}
    end

    updates = {}
    updates[:translation_language] = language.english_name if progress.translation_language != language.english_name
    updates[:data] = {} if progress.data.nil?
    progress.update!(updates) if updates.any?
    progress
  end

  def run_command(environment, command, directory)
    system(environment, *command, chdir: directory)
  rescue Errno::ENOENT => e
    raise "Unable to start the Deno pipeline: #{e.message}"
  end
end
