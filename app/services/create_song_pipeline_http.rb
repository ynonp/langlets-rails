require "net/http"

# Triggers the Deno pipeline over HTTP — the remote counterpart of
# CreateSongPipelineCli's local `deno task cli` subprocess, and the "trigger"
# half that pipeline/README.md lists as the last piece of the cutover.
#
# Uses the synchronous /run form rather than ?async=1 on purpose: the pipeline
# streams every mutation back to PipelineCallbacksController as it goes, so the
# response we block on carries no data — only the verdict. Blocking is what
# lets CreateCourseJob keep its existing shape, where the course is built from
# the finished blob and a raise refunds the import.
class CreateSongPipelineHttp
  class TriggerError < StandardError; end
  class ConfigurationError < StandardError; end

  # A full run is LLM work plus forced alignment over the whole clip: minutes,
  # not seconds. The cap only exists so a hung run can't pin a worker forever.
  # Keep it under the pipeline nginx proxy_read_timeout, or nginx cuts the
  # connection first and we lose the verdict for a run that is still going.
  READ_TIMEOUT = Integer(ENV.fetch("PIPELINE_READ_TIMEOUT", 3_000))
  OPEN_TIMEOUT = 15

  class << self
    # Required: the AI steps only exist in the pipeline now, so there is no
    # in-process path to fall back to. Failing here with something readable
    # beats a KeyError from deep inside a worker.
    def base_url
      url = ENV["PIPELINE_URL"].presence
      raise ConfigurationError, "PIPELINE_URL is not configured; the AI pipeline runs out of process" if url.nil?

      url.delete_suffix("/")
    end

    # Where the pipeline posts its patches back to. In development this is the
    # ngrok tunnel to the local Rails, not localhost — the pipeline runs on
    # another host and localhost there is itself.
    def callback_base_url
      ENV["PIPELINE_CALLBACK_BASE_URL"].delete_suffix("/")
    end
  end

  # language: nil runs the record's own translation_language. Pass one to run a
  # different target (the extra languages other imports asked for).
  # transport is the injection point tests use, mirroring the CLI service's
  # command_runner: it takes the signed body and returns [status, body].
  def initialize(progress:, language: nil, transport: nil)
    @progress = progress
    @language = language
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

    verdict = parse(response_body)

    # Branches settle independently and persist as they go, so a partial
    # failure leaves real work behind — the retrigger picks it up. But the
    # course must not be built from a half-filled blob, so this raises.
    unless verdict["ok"]
      raise TriggerError, "pipeline run failed: #{verdict['failed'].to_json}"
    end

    # Every mutation arrived through the callback, so our in-memory copy is
    # stale by definition.
    @progress.reload
  end

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

  # translation_language: null is legal — it runs transcription + lessons only.
  def language_ref
    language = @language || Language.find_by(english_name: @progress.translation_language)
    return nil if language.nil?

    { id: language.id, iso_name: language.iso_name, english_name: language.english_name }
  end

  def post(body)
    uri = URI.parse("#{self.class.base_url}/run")
    request = Net::HTTP::Post.new(uri)
    PipelineHmac.signed_headers(body).each { |name, value| request[name] = value }
    request.body = body

    response = Net::HTTP.start(
      uri.hostname,
      uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT
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
