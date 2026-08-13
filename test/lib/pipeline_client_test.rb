require "test_helper"

class PipelineClientTest < ActiveSupport::TestCase
  Response = Data.define(:code, :body)

  setup do
    @old_secret = ENV["PIPELINE_HMAC_SECRET"]
    @old_url = Rails.configuration.x.pipeline.url
    ENV["PIPELINE_HMAC_SECRET"] = "test-pipeline-secret"
    Rails.configuration.x.pipeline.url = "https://pipeline.test/"
  end

  teardown do
    ENV["PIPELINE_HMAC_SECRET"] = @old_secret
    Rails.configuration.x.pipeline.url = @old_url
  end

  test "posts signed asynchronous runs to the configured pipeline" do
    request = capture_request(Response.new("202", { accepted: true }.to_json)) do
      assert_equal({ "accepted" => true }, PipelineClient.run({ youtubeurl: "video" }))
    end

    assert_equal "/run?async=1", request.path
    assert_equal({ "youtubeurl" => "video" }, JSON.parse(request.body))
    assert PipelineHmac.verify(
      request[PipelineHmac::TIMESTAMP_HEADER],
      request.body,
      request[PipelineHmac::SIGNATURE_HEADER]
    )
  end

  test "uses the blocking run endpoint when requested" do
    request = capture_request(Response.new("200", { ok: true }.to_json)) do
      PipelineClient.run({ youtubeurl: "video" }, wait: true)
    end

    assert_equal "/run", request.path
  end

  test "uses the language detection endpoint" do
    request = capture_request(Response.new("200", { language: { iso_name: "es" } }.to_json)) do
      PipelineClient.detect_language(youtubeurl: "video", supported_languages: [])
    end

    assert_equal "/detect-language", request.path
  end

  test "raises readable errors for rejected and malformed responses" do
    error = assert_raises(PipelineClient::Error) do
      capture_request(Response.new("401", "invalid signature")) { PipelineClient.run({}) }
    end
    assert_match(/401: invalid signature/, error.message)

    error = assert_raises(PipelineClient::Error) do
      capture_request(Response.new("200", "not json")) { PipelineClient.run({}) }
    end
    assert_match(/unreadable response/, error.message)
  end

  test "requires pipeline configuration" do
    Rails.configuration.x.pipeline.url = nil

    error = assert_raises(PipelineClient::ConfigurationError) { PipelineClient.base_url }

    assert_match(/PIPELINE_URL is not configured/, error.message)
  end

  private

  def capture_request(response)
    captured = nil
    http = Object.new
    http.define_singleton_method(:request) do |request|
      captured = request
      response
    end

    start = ->(*arguments, **options, &block) { block.call(http) }
    Net::HTTP.stub(:start, start) { yield }
    captured
  end
end
