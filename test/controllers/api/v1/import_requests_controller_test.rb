require "test_helper"
require "minitest/mock"

class Api::V1::ImportRequestsControllerTest < ActionDispatch::IntegrationTest
  VIDEO_ID = "kJQP7kiw5Fk".freeze
  CANONICAL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

  setup do
    @user    = User.create!(email: "api-import@example.com", password: "password123", confirmed_at: Time.zone.now)
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
    assert_equal 2, body["credits_left"]
    assert body["thumbnail_url"].present?
  end

  test "an already published video comes back ready, free" do
    course = Course.create!(name: "Despacito", slug: "despacito-published", main_media_url: CANONICAL,
                            youtube_video_id: VIDEO_ID, language: @spanish, translation_language: @english,
                            user: @user, status: :published)

    stub_video { post api_v1_import_requests_url, params: import_params, headers: auth_headers(@token) }

    assert_response :ok
    body = response.parsed_body
    assert_equal "ready", body["status"]
    assert_equal course.slug, body.dig("course", "slug")
    assert_equal 3, body["credits_left"], "the Library costs nothing"
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

  test "returns 422 for a language we don't teach" do
    stub_video do
      post api_v1_import_requests_url,
           params: import_params(clip_language: "Klingon"), headers: auth_headers(@token)
    end

    assert_response :unprocessable_entity
    assert_equal "unsupported_language", response.parsed_body["error"]
  end

  test "requires url and both languages" do
    [ :url, :clip_language, :translation_language ].each do |missing|
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
    Youtube::Oembed.stub(:fetch, ->(_url) { video }, &block)
  end
end
