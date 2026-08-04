require "test_helper"

class PipelineCallbacksControllerTest < ActionDispatch::IntegrationTest
  SECRET = "test-callback-secret"

  setup do
    @previous_secret = ENV["PIPELINE_HMAC_SECRET"]
    ENV["PIPELINE_HMAC_SECRET"] = SECRET

    @progress = CreateSongProgress.create!(
      youtubeurl: "https://www.youtube.com/watch?v=callback-test",
      clip_language: "French",
      data: {}
    )
  end

  teardown do
    ENV["PIPELINE_HMAC_SECRET"] = @previous_secret
  end

  test "applies signed patch ops and persists them" do
    body = {
      ops: [
        { op: "set", path: "lessons", value: "# Lesson\nline" },
        { op: "set", path: "translations.he.phrases.1.text", value: "שלום" },
        { op: "append", path: "errors", value: { step: "translate", error_message: "boom" } }
      ]
    }.to_json

    post pipeline_callback_path(@progress), params: body, headers: PipelineHmac.signed_headers(body)

    assert_response :success
    @progress.reload
    assert_equal "# Lesson\nline", @progress.data["lessons"]
    assert_equal "שלום", @progress.data.dig("translations", "he", "phrases", 1, "text")
    assert_equal "translate", @progress.data.dig("errors", 0, "step")
  end

  test "initialises a nil data blob before patching" do
    @progress.update_column(:data, nil)
    body = { ops: [ { op: "set", path: "video_length_seconds", value: 100 } ] }.to_json

    post pipeline_callback_path(@progress), params: body, headers: PipelineHmac.signed_headers(body)

    assert_response :success
    assert_equal 100, @progress.reload.data["video_length_seconds"]
  end

  test "clears only errors for an action that succeeded after resume" do
    @progress.update!(data: {
      "errors" => [
        { "step" => "translate", "error_message" => "old" },
        { "step" => "rate_lessons", "error_message" => "current" }
      ]
    })
    body = { ops: [ { op: "clear_errors", path: "errors", value: "translate" } ] }.to_json

    post pipeline_callback_path(@progress), params: body, headers: PipelineHmac.signed_headers(body)

    assert_response :success
    assert_equal [ "rate_lessons" ], @progress.reload.data["errors"].map { |error| error["step"] }
  end

  test "rejects an unsigned request" do
    body = { ops: [ { op: "set", path: "lessons", value: "x" } ] }.to_json

    post pipeline_callback_path(@progress), params: body,
         headers: { "Content-Type" => "application/json" }

    assert_response :unauthorized
    assert_nil @progress.reload.data["lessons"]
  end

  test "rejects a tampered body" do
    body = { ops: [ { op: "set", path: "lessons", value: "x" } ] }.to_json
    headers = PipelineHmac.signed_headers(body)
    tampered = { ops: [ { op: "set", path: "lessons", value: "evil" } ] }.to_json

    post pipeline_callback_path(@progress), params: tampered, headers: headers

    assert_response :unauthorized
  end

  test "rejects a stale timestamp" do
    body = { ops: [] }.to_json
    stale = 1.hour.ago.to_i.to_s
    headers = {
      "Content-Type" => "application/json",
      PipelineHmac::TIMESTAMP_HEADER => stale,
      PipelineHmac::SIGNATURE_HEADER => PipelineHmac.sign(stale, body)
    }

    post pipeline_callback_path(@progress), params: body, headers: headers

    assert_response :unauthorized
  end

  test "404s for an unknown record without leaking whether the id exists to unsigned callers" do
    body = { ops: [] }.to_json

    # Unsigned first: authentication is checked before the lookup.
    post "/pipeline_callbacks/999999", params: body,
         headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized

    post "/pipeline_callbacks/999999", params: body, headers: PipelineHmac.signed_headers(body)
    assert_response :not_found
  end

  test "rejects invalid ops with 422 and persists nothing" do
    body = {
      ops: [
        { op: "set", path: "lessons", value: "kept?" },
        { op: "append", path: "lessons", value: "append onto a string" }
      ]
    }.to_json

    post pipeline_callback_path(@progress), params: body, headers: PipelineHmac.signed_headers(body)

    assert_response :unprocessable_entity
    # The whole batch rolls back — partial application would desync the
    # pipeline's local copy from ours.
    assert_nil @progress.reload.data["lessons"]
  end

  test "rejects a body without ops" do
    body = { nope: [] }.to_json

    post pipeline_callback_path(@progress), params: body, headers: PipelineHmac.signed_headers(body)

    assert_response :unprocessable_entity
  end

  test "keeps import request progress in sync via the model's after_save" do
    user = User.create!(
      email: "pipeline-callback@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    import_request = ImportRequest.create!(
      user: user,
      youtube_url: @progress.youtubeurl,
      youtube_video_id: "callback-test",
      clip_language: @progress.clip_language,
      translation_language: "Hebrew",
      status: :importing,
      progress_percent: 0,
      create_song_progress_id: @progress.id
    )

    body = {
      ops: [ { op: "set", path: "lessons", value: "# Lesson\nline" } ]
    }.to_json

    post pipeline_callback_path(@progress), params: body, headers: PipelineHmac.signed_headers(body)

    assert_response :success
    assert_equal @progress.reload.progress_percent, import_request.reload.progress_percent
  end

  # There is no "run finished" callback to wait for, so completion is re-derived
  # after every batch. A patch that leaves work outstanding must not drag the
  # finalizer — and the course build behind it — onto the callback's critical
  # path.
  test "a patch that leaves work outstanding does not enqueue the finalizer" do
    body = { ops: [ { op: "set", path: "lessons", value: "# Lesson\nline" } ] }.to_json

    assert_no_enqueued_jobs(only: FinalizeImportsJob) do
      post pipeline_callback_path(@progress), params: body, headers: PipelineHmac.signed_headers(body)
    end

    assert_response :success
  end

  test "the patch that completes the run enqueues the finalizer" do
    @progress.update!(data: {
      "phrases" => [ { "text_l1" => "bonjour", "words" => [ { "word" => "bonjour" } ] } ],
      "lessons" => "# Lesson\nline",
      "lesson_ratings" => [ 5 ],
      "translations" => { "he" => { "phrases" => [ { "text" => "שלום", "words" => [ "שלום" ] } ] } }
    })
    body = { ops: [ { op: "set", path: "similar_sounds", value: "bonjour: bonsoir" } ] }.to_json

    assert_enqueued_with(job: FinalizeImportsJob, args: [ @progress.id ]) do
      post pipeline_callback_path(@progress), params: body, headers: PipelineHmac.signed_headers(body)
    end

    assert_response :success
  end

  # A reported failure is the other reason to look: it may be one the import
  # should not sit through the full timeout for.
  test "a reported failure enqueues the finalizer" do
    body = {
      ops: [ { op: "append", path: "errors",
               value: { step: "extract_lyrics", error_message: "video is private" } } ]
    }.to_json

    assert_enqueued_with(job: FinalizeImportsJob, args: [ @progress.id ]) do
      post pipeline_callback_path(@progress), params: body, headers: PipelineHmac.signed_headers(body)
    end

    assert_response :success
  end
end
