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

  # The URL stored here becomes the course's main_media_url, and Course#video_id,
  # #provider and #thumbnail_url are all derived from that string. A row keyed on
  # a share link would build a course with no video id — no player, no cover.
  test "resolves a TikTok share link to its canonical post URL" do
    canonical = "https://www.tiktok.com/@scout2015/video/6718335390845095173"
    video = VideoSource::Video.new(
      provider: :tiktok, video_id: "6718335390845095173", title: "Scout",
      author_name: "scout2015", thumbnail_url: "https://cdn.example/c.jpg",
      canonical_url: canonical
    )

    progress = Tiktok::Oembed.stub(:fetch, ->(_url) { video }) do
      CreateSongPipelineCli.new(
        youtube_url: "https://vt.tiktok.com/ZSXvNVQwY/",
        clip_language: "Spanish",
        translation_language: "Hebrew",
        command_runner: ->(*) { true }
      ).call
    end

    assert_equal canonical, progress.youtubeurl
    assert_equal "6718335390845095173", Course.new(main_media_url: progress.youtubeurl).video_id
  end

  test "canonicalizes a TikTok post URL without a network call" do
    progress = Tiktok::Oembed.stub(:fetch, ->(_url) { flunk "must not need oEmbed" }) do
      CreateSongPipelineCli.new(
        youtube_url: "https://www.tiktok.com/@scout2015/video/6718335390845095173?is_from_webapp=1",
        clip_language: "Spanish",
        translation_language: "Hebrew",
        command_runner: ->(*) { true }
      ).call
    end

    assert_equal "https://www.tiktok.com/@scout2015/video/6718335390845095173", progress.youtubeurl
  end

  # Better than spending a whole pipeline run to build an unplayable course.
  test "an unresolvable share link aborts before the CLI runs" do
    unavailable = ->(_url) { raise VideoSource::UnavailableVideo, "video does not exist" }

    assert_raises(ArgumentError) do
      Tiktok::Oembed.stub(:fetch, unavailable) do
        CreateSongPipelineCli.new(
          youtube_url: "https://vt.tiktok.com/ZGONE/",
          clip_language: "Spanish",
          translation_language: "Hebrew",
          command_runner: ->(*) { flunk "should not run" }
        ).call
      end
    end
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
