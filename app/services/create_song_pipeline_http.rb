require "net/http"

# Starts the Deno pipeline over HTTP and gets out of the way.
#
# The default form POSTs `/run?async=1`: the pipeline answers 202 as soon as it
# has accepted the payload and then streams every mutation back to
# PipelineCallbacksController on its own. Nothing here waits for the run, so a
# worker that starts an import is free again in milliseconds and one process
# can have any number of imports in flight.
#
# That is also why this class no longer reports a verdict. A trigger either got
# the run started or it didn't; what the run *produced* is a question you ask of
# CreateSongProgress#data (see Imports::Finalizer), because the callbacks are
# the only thing that can answer it. The old blocking form is kept behind
# `wait: true` for the rake tasks, which run a pipeline and then immediately
# export the record from the same process.
class CreateSongPipelineHttp
  class TriggerError < StandardError; end
  class ConfigurationError < StandardError; end

  # Accepting the payload is a few milliseconds of work; anything slower than
  # this is the pipeline being unreachable, which we want to hear about now
  # rather than after a long stall.
  TRIGGER_READ_TIMEOUT = 30

  # Only used by `wait: true`. A full run is LLM work plus forced alignment over
  # the whole clip: minutes, not seconds. Keep it under the pipeline nginx
  # proxy_read_timeout, or nginx cuts the connection first and we lose the
  # verdict for a run that is still going.
  READ_TIMEOUT = Integer(ENV.fetch("PIPELINE_READ_TIMEOUT", 3_000))
  OPEN_TIMEOUT = 15

  class << self
    # Required: the AI steps only exist in the pipeline now, so there is no
    # in-process path to fall back to. Failing here with something readable
    # beats a KeyError from deep inside a worker.
    def base_url
      url = Rails.configuration.x.pipeline.url.presence
      raise ConfigurationError, "PIPELINE_URL is not configured; the AI pipeline runs out of process" if url.nil?

      url.delete_suffix("/")
    end

    # Where the pipeline posts its patches back to. In development this is the
    # ngrok tunnel to the local Rails, not localhost — the pipeline runs on
    # another host and localhost there is itself.
    def callback_base_url
      Rails.configuration.x.pipeline.callback_base_url.delete_suffix("/")
    end

    # The pipeline's first focused request. YouTube uses Gemini 2.5 Flash;
    # TikTok returns ElevenLabs' detected code together with the transcript so
    # the subsequent full run can resume without transcribing twice.
    def detect_language(url:, transport: nil)
      languages = Language.order(:id).pluck(:iso_name, :english_name).map do |iso_name, english_name|
        { iso_name: iso_name, english_name: english_name }
      end
      body = { youtubeurl: url, supported_languages: languages }.to_json
      status, response_body = (transport || method(:post_detection)).call(body)
      parsed = JSON.parse(response_body.to_s)
      unless status.between?(200, 299)
        raise TriggerError, "language detection failed: #{parsed['error'] || response_body.to_s.truncate(500)}"
      end

      language = Language.find_by!(iso_name: parsed.dig("language", "iso_name"))
      [ language, parsed["data"].presence || {} ]
    rescue JSON::ParserError, ActiveRecord::RecordNotFound => e
      raise TriggerError, "language detection returned an unreadable language: #{e.message}"
    end

    private

    def post_detection(body)
      uri = URI.parse("#{base_url}/detect-language")
      request = Net::HTTP::Post.new(uri)
      PipelineHmac.signed_headers(body).each { |name, value| request[name] = value }
      request.body = body
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https",
                                 open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(request)
      end
      [ response.code.to_i, response.body ]
    rescue Net::OpenTimeout, Net::ReadTimeout, SystemCallError, SocketError, OpenSSL::SSL::SSLError => e
      raise TriggerError, "could not detect the video language: #{e.message}"
    end
  end

  # language: nil runs the record's own translation_language. Pass one to run a
  # different target (the extra languages other imports asked for).
  # wait: true blocks until the run finishes and raises unless every branch
  # succeeded — the rake tasks' shape, never a worker's.
  # transport is the injection point tests use, mirroring the CLI service's
  # command_runner: it takes the signed body and returns [status, body].
  def initialize(progress:, language: nil, wait: false, transport: nil)
    @progress = progress
    @language = language
    @wait = wait
    @transport = transport || method(:post)
  end

  def call
    raise ArgumentError, "PIPELINE_HMAC_SECRET is not configured" if PipelineHmac.secret.blank?
    raise ArgumentError, "CreateSongProgress must be persisted" unless @progress.persisted?

    status, response_body = @transport.call(payload.to_json)

    unless status.between?(200, 299)
      raise TriggerError,
            "pipeline #{self.class.base_url} returned #{status}: #{response_body.to_s.truncate(500)}"
    end

    return true unless @wait

    verdict = parse(response_body)

    # Branches settle independently and persist as they go, so a partial
    # failure leaves real work behind — the retrigger picks it up.
    raise TriggerError, "pipeline run failed: #{verdict['failed'].to_json}" unless verdict["ok"]

    # Every mutation arrived through the callback, so our in-memory copy is
    # stale by definition.
    @progress.reload
  end

  # `?async=1` is the whole difference between triggering and waiting: it makes
  # the pipeline answer 202 the moment it has the payload and run in the
  # background, reporting through the callback instead of the response.
  def trigger_url = "#{self.class.base_url}/run#{@wait ? '' : '?async=1'}"

  private

  def payload
    {
      youtubeurl: @progress.youtubeurl,
      clip_language: @progress.clip_language,
      translation_language: language_ref,
      callback_url: "#{self.class.callback_base_url}/pipeline_callbacks/#{@progress.id}",
      # The saved blob is what makes a retrigger resume instead of redo: every
      # step is guarded by the same predicates create_data used.
      data: @progress.data || {}
    }
  end

  # No clip_language_iso: the pipeline derives the transcription code from the
  # clip language name itself. Language#iso_name is a TTS code — Arabic is
  # ar-JO, chosen for its Azure voice — and asking Supadata for a caption track
  # in a regional variant it does not stock is worse than asking for `ar`.
  #
  # translation_language: null is legal — it runs transcription + lessons only.
  def language_ref
    language = @language || Language.find_by(english_name: @progress.translation_language)
    return nil if language.nil?

    { id: language.id, iso_name: language.iso_name, english_name: language.english_name }
  end

  def post(body)
    uri = URI.parse(trigger_url)
    request = Net::HTTP::Post.new(uri)
    PipelineHmac.signed_headers(body).each { |name, value| request[name] = value }
    request.body = body

    response = Net::HTTP.start(
      uri.hostname,
      uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: OPEN_TIMEOUT,
      read_timeout: @wait ? READ_TIMEOUT : TRIGGER_READ_TIMEOUT
    ) { |http| http.request(request) }

    [ response.code.to_i, response.body ]
  rescue Net::OpenTimeout, Net::ReadTimeout, SystemCallError, SocketError, OpenSSL::SSL::SSLError => e
    # The run may well still be going on the pipeline host; the callbacks it
    # already delivered are saved, so retriggering resumes rather than redoes.
    raise TriggerError, "could not reach the pipeline at #{self.class.base_url}: #{e.message}"
  end

  def parse(body)
    JSON.parse(body.to_s)
  rescue JSON::ParserError => e
    raise TriggerError, "pipeline returned an unreadable response: #{e.message}"
  end
end
