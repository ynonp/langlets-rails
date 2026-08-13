require "tempfile"

class CreateSongPipelineCli
  def initialize(youtube_url:, clip_language:, translation_language:, callback_base_url:, command_runner: nil)
    @youtube_url = youtube_url
    @clip_language = clip_language
    @translation_language_name = translation_language
    @callback_base_url = callback_base_url
    @command_runner = command_runner || method(:run_command)
  end

  def call
    secret = PipelineHmac.secret
    raise ArgumentError, "PIPELINE_HMAC_SECRET is not configured" if secret.blank?

    language = Language.find_by(english_name: @translation_language_name) ||
      Language.find_by(iso_name: @translation_language_name)
    raise ArgumentError, "unknown translation language: #{@translation_language_name}" unless language

    progress = find_or_create_progress(resolve_url)

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

  # The web path canonicalizes in Imports::Create before a progress row exists;
  # this one has to do it itself, and getting it wrong is not cosmetic. The URL
  # stored here becomes the course's main_media_url, and Course#video_id /
  # #provider / #thumbnail_url are all derived from that string — so a row keyed
  # on a TikTok share link (vt.tiktok.com/ZSXvNVQwY, which carries a redirect
  # token rather than a post id) yields a course with no video id at all: no
  # player, no cover.
  #
  # Offline first, so a URL no provider claims — including the fake ones tests
  # use — passes through untouched rather than being rejected here.
  def resolve_url
    return VideoSource.canonical(@youtube_url) if VideoSource.video_id(@youtube_url).present?
    return @youtube_url if VideoSource.provider(@youtube_url).nil?

    # A share link: only the provider's oEmbed can turn it into a post id.
    # Failing loudly beats spending a whole pipeline run to build an unplayable
    # course.
    VideoSource.fetch(@youtube_url).canonical_url
  rescue VideoSource::UnavailableVideo => e
    raise ArgumentError, "could not resolve #{@youtube_url.inspect}: #{e.message}"
  end

  def find_or_create_progress(url)
    progress = CreateSongProgress.find_or_create_by!(
      youtubeurl: url,
      clip_language: @clip_language
    ) do |record|
      record.data = {}
    end

    progress.update!(data: {}) if progress.data.nil?
    progress
  end

  def run_command(environment, command, directory)
    system(environment, *command, chdir: directory)
  rescue Errno::ENOENT => e
    raise "Unable to start the Deno pipeline: #{e.message}"
  end
end
