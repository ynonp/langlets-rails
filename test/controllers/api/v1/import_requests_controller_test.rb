require "test_helper"
require "minitest/mock"

class Api::V1::ImportRequestsControllerTest < ActionDispatch::IntegrationTest
  VIDEO_ID = "kJQP7kiw5Fk".freeze
  CANONICAL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

  setup do
    @user    = User.create!(email: "api-import@example.com", password: "password123", confirmed_at: Time.zone.now)
    @other   = User.create!(email: "api-other@example.com", password: "password123", confirmed_at: Time.zone.now)
    @spanish = languages(:spanish)
    @english = languages(:english)
    @token   = create_access_token(@user, scopes: "imports:write imports:read")
  end

  test "requires a bearer token and advertises resource metadata" do
    post api_v1_import_requests_url, params: import_params

    assert_response :unauthorized
    assert_includes @response.headers["WWW-Authenticate"], "resource_metadata="
  end

  # imports:write is never a default scope — importing spends the user's money.
  test "rejects a token without imports:write" do
    read_only = create_access_token(@user, scopes: "courses:read")

    post api_v1_import_requests_url, params: import_params, headers: auth_headers(read_only)

    assert_response :forbidden
    assert_equal "insufficient_scope", response.parsed_body["error"]
  end

  test "creates an import and reports the balance left" do
    stub_video { post api_v1_import_requests_url, params: import_params, headers: auth_headers(@token) }

    assert_response :created
    body = response.parsed_body
    assert_equal "queued", body["status"]
    assert_equal "Despacito", body["title"]
    assert_equal VIDEO_ID, body["youtube_video_id"]
    assert_equal 3, body["credits_left"], "queued, not delivered — the credit moves when it publishes"
    assert body["thumbnail_url"].present?
  end

  test "replaying a client token returns the original import without another charge" do
    params = import_params.merge(client_token: "share-request-123")
    stub_video { post api_v1_import_requests_url, params: params, headers: auth_headers(@token) }
    original_id = response.parsed_body.fetch("id")

    post api_v1_import_requests_url, params: params, headers: auth_headers(@token)

    assert_response :success
    assert_equal original_id, response.parsed_body.fetch("id")
    assert_equal 3, response.parsed_body.fetch("credits_left")
    assert_equal 1, @user.import_requests.count
  end

  # No pipeline to run, so the share extension gets its answer immediately — and
  # the course is published into the sharer's channel there and then, which is
  # what the credit pays for.
  test "an already published video comes back ready, and is paid for on the spot" do
    course = create_translated_course!(name: "Despacito", slug: "despacito-published", main_media_url: CANONICAL,
                            youtube_video_id: VIDEO_ID, language: @spanish, translation_language: @english,
                            user: @other, status: :published)

    stub_video { post api_v1_import_requests_url, params: import_params, headers: auth_headers(@token) }

    assert_response :ok
    body = response.parsed_body
    assert_equal "ready", body["status"]
    assert_equal course.slug, body.dig("course", "slug")
    assert_equal 2, body["credits_left"]
    assert @user.default_channel.channel_items.exists?(course: course)
  end

  test "a video already in the sharer's own channel comes back ready and free" do
    course = create_translated_course!(name: "Despacito", slug: "despacito-mine", main_media_url: CANONICAL,
                            youtube_video_id: VIDEO_ID, language: @spanish, translation_language: @english,
                            user: @other, status: :published)
    publish_covering_the_credit(@user.provision_default_channel!, course)

    stub_video { post api_v1_import_requests_url, params: import_params, headers: auth_headers(@token) }

    assert_response :ok
    assert_equal "ready", response.parsed_body["status"]
    assert_equal 3, response.parsed_body["credits_left"], "nothing left to publish"
  end

  test "returns 402 when out of credits" do
    User.where(id: @user.id).update_all(credit_balance: 0)

    stub_video { post api_v1_import_requests_url, params: import_params, headers: auth_headers(@token) }

    assert_response :payment_required
    assert_equal "insufficient_credits", response.parsed_body["error"]
    assert_equal 0, response.parsed_body["credits_left"]
  end

  test "returns 422 for a private or deleted video, and charges nothing" do
    Youtube::Oembed.stub(:fetch, ->(_url) { raise Youtube::Oembed::UnavailableVideo, "video is private" }) do
      post api_v1_import_requests_url, params: import_params, headers: auth_headers(@token)
    end

    assert_response :unprocessable_entity
    assert_equal "unavailable_video", response.parsed_body["error"]
    assert_equal 3, @user.reload.credit_balance
  end

  test "returns 422 when automatic language detection fails" do
    video = Youtube::Oembed::Video.new(
      video_id: VIDEO_ID, title: "Despacito", author_name: "Luis Fonsi",
      thumbnail_url: "https://i.ytimg.com/vi/#{VIDEO_ID}/hqdefault.jpg", canonical_url: CANONICAL
    )
    Youtube::Oembed.stub(:fetch, ->(_url) { video }) do
      CreateSongPipelineHttp.stub(:detect_language, ->(**) { raise CreateSongPipelineHttp::TriggerError, "unsupported" }) do
        post api_v1_import_requests_url, params: import_params.except(:clip_language), headers: auth_headers(@token)
      end
    end

    assert_response :unprocessable_entity
    assert_equal "language_detection_failed", response.parsed_body["error"]
    assert_equal 3, @user.reload.credit_balance
  end

  test "requires url and translation language" do
    [ :url, :translation_language ].each do |missing|
      post api_v1_import_requests_url, params: import_params.except(missing), headers: auth_headers(@token)

      assert_response :unprocessable_entity
      assert_equal "missing_parameter", response.parsed_body["error"], "expected #{missing} to be required"
    end
  end

  test "lists the user's queue" do
    stub_video { post api_v1_import_requests_url, params: import_params, headers: auth_headers(@token) }

    get api_v1_import_requests_url, headers: auth_headers(@token)

    assert_response :success
    assert_equal 1, response.parsed_body["import_requests"].size
    assert_equal "queued", response.parsed_body["import_requests"].first["status"]
  end

  test "the queue only shows your own imports" do
    other = User.create!(email: "someone-else@example.com", password: "password123", confirmed_at: Time.zone.now)
    other.import_requests.create!(youtube_url: CANONICAL, youtube_video_id: VIDEO_ID,
                                  clip_language: "Spanish", translation_language: "English", status: :queued)

    get api_v1_import_requests_url, headers: auth_headers(@token)

    assert_response :success
    assert_empty response.parsed_body["import_requests"]
  end

  # The iOS share extension's real payload: TikTok's share sheet hands out a
  # vt.tiktok.com link, which carries a redirect token rather than a post id.
  # Only oEmbed can resolve one, so this is the path that proves the extension
  # can import at all.
  test "imports a TikTok share link, resolving it to a post id" do
    stub_tiktok do
      post api_v1_import_requests_url,
           params: import_params(url: TIKTOK_SHORT),
           headers: auth_headers(@token)
    end

    assert_response :created
    body = response.parsed_body
    assert_equal "queued", body["status"]
    assert_equal TIKTOK_ID, body["youtube_video_id"]
    assert_equal 3, body["credits_left"]
  end

  # TikTok covers can't be derived from the URL, so if the value oEmbed returned
  # wasn't stored at import time the Queue card would have nothing to render.
  test "a TikTok import carries the cover oEmbed returned" do
    stub_tiktok do
      post api_v1_import_requests_url,
           params: import_params(url: TIKTOK_SHORT),
           headers: auth_headers(@token)
    end

    assert_equal TIKTOK_THUMB, response.parsed_body["thumbnail_url"]
    course = ImportRequest.find(response.parsed_body.fetch("id")).course
    assert_equal TIKTOK_THUMB, course.thumbnail_url
    assert course.tiktok?
  end

  private

  def import_params(clip_language: "Spanish", translation_language: "English", url: CANONICAL)
    { url: url, clip_language: clip_language, translation_language: translation_language }
  end

  def stub_video(&block)
    video = Youtube::Oembed::Video.new(
      video_id: VIDEO_ID, title: "Despacito", author_name: "Luis Fonsi",
      thumbnail_url: "https://i.ytimg.com/vi/#{VIDEO_ID}/hqdefault.jpg",
      canonical_url: CANONICAL
    )
    CreateSongPipelineHttp.stub(:detect_language, [ @spanish, {} ]) do
      Youtube::Oembed.stub(:fetch, ->(_url) { video }, &block)
    end
  end

  TIKTOK_SHORT = "https://vt.tiktok.com/ZSXvNVQwY/".freeze
  TIKTOK_ID = "6718335390845095173".freeze
  TIKTOK_CANONICAL = "https://www.tiktok.com/@scout2015/video/#{TIKTOK_ID}".freeze
  TIKTOK_THUMB = "https://p16-sign-va.tiktokcdn.com/obj/abc?x-expires=1&x-signature=z".freeze

  def stub_tiktok(&block)
    video = VideoSource::Video.new(
      provider: :tiktok, video_id: TIKTOK_ID, title: "Scout and Suki",
      author_name: "scout2015", thumbnail_url: TIKTOK_THUMB,
      canonical_url: TIKTOK_CANONICAL
    )
    CreateSongPipelineHttp.stub(:detect_language, [ @spanish, {
      "lyric_lines" => [ "hola" ], "stt_words" => []
    } ]) do
      Tiktok::Oembed.stub(:fetch, ->(_url) { video }, &block)
    end
  end
end
