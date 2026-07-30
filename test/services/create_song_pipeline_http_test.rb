require "test_helper"

class CreateSongPipelineHttpTest < ActiveSupport::TestCase
  setup do
    CreateSongProgress.delete_all
    @secret = "test-pipeline-secret"
    @old_secret = ENV["PIPELINE_HMAC_SECRET"]
    @old_url = Rails.configuration.x.pipeline.url
    @old_callback = Rails.configuration.x.pipeline.callback_base_url
    ENV["PIPELINE_HMAC_SECRET"] = @secret
    Rails.configuration.x.pipeline.url = "https://pipeline.test/"
    Rails.configuration.x.pipeline.callback_base_url = "https://tunnel.test/"

    @progress = CreateSongProgress.create!(
      youtubeurl: "https://www.youtube.com/watch?v=XXXX",
      clip_language: "French",
      translation_language: "Hebrew",
      data: { "phrases" => [ { "text_l1" => "bonjour" } ] }
    )
  end

  teardown do
    ENV["PIPELINE_HMAC_SECRET"] = @old_secret
    Rails.configuration.x.pipeline.url = @old_url
    Rails.configuration.x.pipeline.callback_base_url = @old_callback
  end

  test "posts the record's saved data and the tunnelled callback url" do
    sent = nil
    trigger(transport: ->(body) { sent = JSON.parse(body); ok })

    assert_equal "https://www.youtube.com/watch?v=XXXX", sent.fetch("youtubeurl")
    assert_equal "French", sent.fetch("clip_language")
    # The saved blob is what makes a retrigger resume rather than redo.
    assert_equal @progress.data, sent.fetch("data")
    assert_equal "https://tunnel.test/pipeline_callbacks/#{@progress.id}", sent.fetch("callback_url")

    # Deliberately absent: the pipeline derives the transcription code from the
    # clip language name. Language#iso_name is a TTS code (Arabic is ar-JO), and
    # sending it would ask Supadata for caption tracks in regional variants.
    assert_nil sent["clip_language_iso"]

    language = sent.fetch("translation_language")
    assert_equal "he", language.fetch("iso_name")
    assert_equal "Hebrew", language.fetch("english_name")
    assert_equal languages(:hebrew).id, language.fetch("id")
  end

  test "signs the body so the pipeline's verifier accepts it" do
    headers = nil
    transport = lambda do |body|
      headers = PipelineHmac.signed_headers(body)
      # Verifying with the same scheme the pipeline uses is the point: a
      # mismatch here is exactly the 401 a real run would hit.
      assert PipelineHmac.verify(
        headers[PipelineHmac::TIMESTAMP_HEADER],
        body,
        headers[PipelineHmac::SIGNATURE_HEADER]
      )
      ok
    end

    trigger(transport: transport)
    assert headers.present?
  end

  test "runs an explicitly requested language instead of the record's own" do
    sent = nil
    trigger(language: languages(:english), transport: ->(body) { sent = JSON.parse(body); ok })

    assert_equal "en", sent.dig("translation_language", "iso_name")
  end

  # The trigger is fire-and-forget: it asks for ?async=1, so the pipeline's 202
  # means "accepted", not "finished", and there is no verdict in the body.
  test "triggers asynchronously so no worker waits on the run" do
    assert_equal "https://pipeline.test/run?async=1",
                 CreateSongPipelineHttp.new(progress: @progress).trigger_url

    assert trigger(transport: ->(_body) { [ 202, { accepted: true }.to_json ] })
  end

  # The run's own failures arrive through the callback now, so a body that says
  # a branch failed is not this object's business — only the status is.
  test "an accepted trigger ignores whatever the body says" do
    body = { ok: false, failed: { "translate" => "boom" }, summary: {} }.to_json

    assert_nothing_raised { trigger(transport: ->(_body) { [ 200, body ] }) }
    assert_nothing_raised { trigger(transport: ->(_body) { [ 200, "<html>not json</html>" ] }) }
  end

  test "raises on a non-success status" do
    error = assert_raises(CreateSongPipelineHttp::TriggerError) do
      trigger(transport: ->(_body) { [ 401, "invalid signature" ] })
    end

    assert_match(/401/, error.message)
  end

  # The rake tasks run a pipeline and export the record in the same process, so
  # they still need the synchronous form and its verdict.
  test "wait: true uses the blocking form and raises when a branch failed" do
    assert_equal "https://pipeline.test/run",
                 CreateSongPipelineHttp.new(progress: @progress, wait: true).trigger_url

    body = { ok: false, failed: { "translate" => "boom" }, summary: {} }.to_json
    error = assert_raises(CreateSongPipelineHttp::TriggerError) do
      trigger(wait: true, transport: ->(_body) { [ 200, body ] })
    end

    assert_match(/pipeline run failed/, error.message)
    assert_match(/boom/, error.message)
  end

  test "wait: true raises a readable error when the response is not json" do
    error = assert_raises(CreateSongPipelineHttp::TriggerError) do
      trigger(wait: true, transport: ->(_body) { [ 200, "<html>502 Bad Gateway</html>" ] })
    end

    assert_match(/unreadable response/, error.message)
  end

  test "base_url strips a trailing slash" do
    assert_equal "https://pipeline.test", CreateSongPipelineHttp.base_url
  end

  # There is no in-process path left to fall back to, so an unset pipeline URL
  # is a misconfiguration and should say so rather than raise a bare KeyError.
  test "an unconfigured pipeline URL raises a readable error" do
    Rails.configuration.x.pipeline.url = nil

    error = assert_raises(CreateSongPipelineHttp::ConfigurationError) do
      CreateSongPipelineHttp.base_url
    end

    assert_match(/PIPELINE_URL is not configured/, error.message)
  end

  private

  def ok
    [ 200, { ok: true, failed: {}, summary: {} }.to_json ]
  end

  def trigger(transport:, language: nil, wait: false)
    CreateSongPipelineHttp.new(progress: @progress, language: language, wait: wait, transport: transport).call
  end
end
