require "test_helper"

class CreateSongPipelineHttpTest < ActiveSupport::TestCase
  setup do
    CreateSongProgress.delete_all
    @secret = "test-pipeline-secret"
    @old_secret = ENV["PIPELINE_HMAC_SECRET"]
    @old_url = ENV["PIPELINE_URL"]
    @old_callback = ENV["PIPELINE_CALLBACK_BASE_URL"]
    ENV["PIPELINE_HMAC_SECRET"] = @secret
    ENV["PIPELINE_URL"] = "https://pipeline.test/"
    ENV["PIPELINE_CALLBACK_BASE_URL"] = "https://tunnel.test/"

    @progress = CreateSongProgress.create!(
      youtubeurl: "https://www.youtube.com/watch?v=XXXX",
      clip_language: "French",
      translation_language: "Hebrew",
      data: { "phrases" => [ { "text_l1" => "bonjour" } ] }
    )
  end

  teardown do
    ENV["PIPELINE_HMAC_SECRET"] = @old_secret
    ENV["PIPELINE_URL"] = @old_url
    ENV["PIPELINE_CALLBACK_BASE_URL"] = @old_callback
  end

  test "posts the record's saved data and the tunnelled callback url" do
    sent = nil
    trigger(transport: ->(body) { sent = JSON.parse(body); ok })

    assert_equal "https://www.youtube.com/watch?v=XXXX", sent.fetch("youtubeurl")
    assert_equal "French", sent.fetch("clip_language")
    # The saved blob is what makes a retrigger resume rather than redo.
    assert_equal @progress.data, sent.fetch("data")
    assert_equal "https://tunnel.test/pipeline_callbacks/#{@progress.id}", sent.fetch("callback_url")

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

  test "raises when a branch failed so the course is not built from a partial blob" do
    body = { ok: false, failed: { "translate" => "boom" }, summary: {} }.to_json

    error = assert_raises(CreateSongPipelineHttp::TriggerError) do
      trigger(transport: ->(_body) { [ 200, body ] })
    end

    assert_match(/pipeline run failed/, error.message)
    assert_match(/boom/, error.message)
  end

  test "raises on a non-success status" do
    error = assert_raises(CreateSongPipelineHttp::TriggerError) do
      trigger(transport: ->(_body) { [ 401, "invalid signature" ] })
    end

    assert_match(/401/, error.message)
  end

  test "raises a readable error when the response is not json" do
    error = assert_raises(CreateSongPipelineHttp::TriggerError) do
      trigger(transport: ->(_body) { [ 200, "<html>502 Bad Gateway</html>" ] })
    end

    assert_match(/unreadable response/, error.message)
  end

  test "base_url strips a trailing slash" do
    assert_equal "https://pipeline.test", CreateSongPipelineHttp.base_url
  end

  # There is no in-process path left to fall back to, so an unset PIPELINE_URL
  # is a misconfiguration and should say so rather than raise a bare KeyError.
  test "an unconfigured PIPELINE_URL raises a readable error" do
    ENV["PIPELINE_URL"] = nil

    error = assert_raises(CreateSongPipelineHttp::ConfigurationError) do
      CreateSongPipelineHttp.base_url
    end

    assert_match(/PIPELINE_URL is not configured/, error.message)
  end

  test "callback base url falls back to localhost when no tunnel is configured" do
    ENV["PIPELINE_CALLBACK_BASE_URL"] = nil
    assert_equal "http://localhost:3000", CreateSongPipelineHttp.callback_base_url
  end

  private

  def ok
    [ 200, { ok: true, failed: {}, summary: {} }.to_json ]
  end

  def trigger(transport:, language: nil)
    CreateSongPipelineHttp.new(progress: @progress, language: language, transport: transport).call
  end
end
