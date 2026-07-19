require "test_helper"

class CreateSongPipelineCliTest < ActiveSupport::TestCase
  setup do
    CreateSongProgress.delete_all
    @secret = "test-pipeline-secret"
    @old_secret = ENV["PIPELINE_HMAC_SECRET"]
    ENV["PIPELINE_HMAC_SECRET"] = @secret
  end

  teardown do
    ENV["PIPELINE_HMAC_SECRET"] = @old_secret
  end

  test "creates and exports a progress record then waits for the Deno CLI" do
    invocation = nil
    runner = lambda do |environment, command, directory|
      invocation = [ environment, command, directory ]
      payload = JSON.parse(File.read(command[command.index("--input") + 1]))
      assert_equal "https://www.youtube.com/watch?v=XXXX", payload.fetch("youtubeurl")
      assert_equal({}, payload.fetch("data"))
      true
    end

    progress = build_runner(command_runner: runner).call
    environment, command, directory = invocation

    assert_equal @secret, environment.fetch("PIPELINE_HMAC_SECRET")
    assert_equal Rails.root.join("pipeline").to_s, directory
    assert_equal "http://rails.test/pipeline_callbacks/#{progress.id}", command[3]
    assert_equal "he", command[command.index("--iso") + 1]
    assert_equal languages(:hebrew).id.to_s, command[command.index("--lang-id") + 1]
    assert_equal "Hebrew", progress.translation_language
  end

  test "re-exports fresh database state when resuming an existing record" do
    progress = CreateSongProgress.create!(
      youtubeurl: "https://www.youtube.com/watch?v=XXXX",
      clip_language: "French",
      translation_language: "English",
      data: { "phrases" => [ { "text_l1" => "bonjour" } ] }
    )

    runner = lambda do |_environment, command, _directory|
      payload = JSON.parse(File.read(command[command.index("--input") + 1]))
      assert_equal progress.data, payload.fetch("data")
      true
    end

    result = build_runner(command_runner: runner).call

    assert_equal progress.id, result.id
    assert_equal "Hebrew", result.translation_language
  end

  test "raises when the CLI exits unsuccessfully" do
    error = assert_raises(RuntimeError) do
      build_runner(command_runner: ->(*) { false }).call
    end

    assert_match(/Deno pipeline failed/, error.message)
  end

  test "rejects an unknown translation language before invoking the CLI" do
    error = assert_raises(ArgumentError) do
      CreateSongPipelineCli.new(
        youtube_url: "https://www.youtube.com/watch?v=XXXX",
        clip_language: "French",
        translation_language: "Klingon",
        command_runner: ->(*) { flunk "should not run" }
      ).call
    end

    assert_equal "unknown translation language: Klingon", error.message
  end

  private

  def build_runner(command_runner:)
    CreateSongPipelineCli.new(
      youtube_url: "https://www.youtube.com/watch?v=XXXX",
      clip_language: "French",
      translation_language: "Hebrew",
      callback_base_url: "http://rails.test/",
      command_runner: command_runner
    )
  end
end
