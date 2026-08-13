require "test_helper"

class CreateSongPipelineTest < ActiveSupport::TestCase
  setup do
    CreateSongProgress.delete_all
    @old_callback = Rails.configuration.x.pipeline.callback_base_url
    Rails.configuration.x.pipeline.callback_base_url = "https://rails.test/"
    @progress = CreateSongProgress.create!(
      youtubeurl: "https://www.youtube.com/watch?v=XXXX",
      clip_language: "French",
      data: { "phrases" => [ { "text_l1" => "bonjour" } ] }
    )
  end

  teardown do
    Rails.configuration.x.pipeline.callback_base_url = @old_callback
  end

  test "builds the run payload from persisted model state" do
    sent = nil
    PipelineClient.stub(:run, ->(payload, wait:) { sent = [ payload, wait ]; { "accepted" => true } }) do
      assert @progress.run_pipeline(language: languages(:hebrew))
    end

    payload, wait = sent
    assert_not wait
    assert_equal @progress.youtubeurl, payload.fetch(:youtubeurl)
    assert_equal @progress.data, payload.fetch(:data)
    assert_equal "https://rails.test/pipeline_callbacks/#{@progress.id}", payload.fetch(:callback_url)
    assert_equal "he", payload.dig(:translation_language, :iso_name)
  end

  test "waits for a successful run and reloads callback changes" do
    PipelineClient.stub(:run, ->(_payload, wait:) {
      assert wait
      @progress.update_column(:data, { "finished" => true })
      { "ok" => true }
    }) do
      assert_equal({ "finished" => true }, @progress.run_pipeline(wait: true).data)
    end
  end

  test "raises when a blocking run reports failed branches" do
    PipelineClient.stub(:run, { "ok" => false, "failed" => { "translate" => "boom" } }) do
      error = assert_raises(PipelineClient::Error) { @progress.run_pipeline(wait: true) }
      assert_match(/translate/, error.message)
    end
  end

  test "detects language using the database language catalog" do
    sent = nil
    response = {
      "language" => { "iso_name" => "es" },
      "data" => { "stt_words" => [ { "text" => "hola" } ] }
    }
    PipelineClient.stub(:detect_language, ->(payload) { sent = payload; response }) do
      language, data = CreateSongProgress.detect_language(url: @progress.youtubeurl)

      assert_equal languages(:spanish), language
      assert_equal response.fetch("data"), data
    end
    assert_includes sent.fetch(:supported_languages), { iso_name: "ar-JO", english_name: "Arabic" }
  end

  test "finds the progress record and runs the requested translation" do
    sent = nil
    PipelineClient.stub(:run, ->(payload, wait:) { sent = [ payload, wait ]; { "ok" => true } }) do
      result = CreateSongProgress.run_pipeline(
        youtube_url: @progress.youtubeurl,
        clip_language: "French",
        translation_language: "Hebrew",
        wait: true
      )

      assert_equal @progress, result
    end
    assert sent.second
    assert_equal "he", sent.first.dig(:translation_language, :iso_name)
  end

  test "canonicalizes TikTok URLs before creating progress" do
    canonical = "https://www.tiktok.com/@scout2015/video/6718335390845095173"
    video = VideoSource::Video.new(
      provider: :tiktok, video_id: "6718335390845095173", title: "Scout",
      author_name: "scout2015", thumbnail_url: "https://cdn.example/c.jpg",
      canonical_url: canonical
    )

    PipelineClient.stub(:run, { "accepted" => true }) do
      progress = Tiktok::Oembed.stub(:fetch, ->(_url) { video }) do
        CreateSongProgress.run_pipeline(
          youtube_url: "https://vt.tiktok.com/ZSXvNVQwY/",
          clip_language: "Spanish",
          translation_language: "Hebrew"
        )
      end

      assert_equal canonical, progress.youtubeurl
    end
  end
end
