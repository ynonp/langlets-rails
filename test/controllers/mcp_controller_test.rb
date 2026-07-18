require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "mcp@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    @english = languages(:english)
    @spanish = languages(:spanish)

    medium = Medium.create!(url: "https://www.youtube.com/watch?v=mcp1", language: @english)
    phrase = create_translated_phrase!(
      medium: medium, l1: @english, l2: @spanish,
      text_l1: "Hello world", text_l2: "Hola mundo", timestamp: "00:01:30"
    )
    token_translation = create_translated_token!(
      phrase: phrase, l1_start_index: 0, l1_end_index: 4,
      index_type: :character_index, translation: "Hola"
    )
    @user.saved_phrase_tokens << token_translation

    Course.create!(
      name: "MCP Spanish Songs", slug: "mcp-spanish-songs", main_media_url: "https://example.com/1",
      user: @user, language: @spanish, status: :published
    )

    @token = create_access_token(@user)
  end

  def mcp_post(payload, token: @token)
    headers = { "Content-Type" => "application/json", "Accept" => "application/json" }
    headers.merge!(auth_headers(token)) if token
    post "/mcp", params: payload.to_json, headers: headers
  end

  def rpc(method, params = {}, id: 1)
    { jsonrpc: "2.0", id: id, method: method, params: params }
  end

  test "rejects unauthenticated requests with discovery pointer" do
    mcp_post(rpc("initialize"), token: nil)

    assert_response :unauthorized
    assert_includes @response.headers["WWW-Authenticate"],
      %(resource_metadata="http://www.example.com/.well-known/oauth-protected-resource/mcp")
  end

  test "rejects expired tokens" do
    expired = create_access_token(@user)
    expired.update_column(:created_at, 3.hours.ago)

    mcp_post(rpc("initialize"), token: expired)

    assert_response :unauthorized
  end

  test "answers initialize" do
    mcp_post(rpc("initialize", {
      protocolVersion: "2025-03-26",
      capabilities: {},
      clientInfo: { name: "test", version: "1.0" }
    }))

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal "langlets", body.dig("result", "serverInfo", "name")
  end

  test "lists both tools" do
    mcp_post(rpc("tools/list"))

    assert_response :success
    tools = JSON.parse(@response.body).dig("result", "tools")
    names = tools.map { |t| t["name"] }
    assert_includes names, "get_vocabulary"
    assert_includes names, "get_courses"
    get_courses = tools.find { |t| t["name"] == "get_courses" }
    assert_equal [ "language" ], get_courses.dig("inputSchema", "required")
  end

  test "calls get_vocabulary" do
    mcp_post(rpc("tools/call", { name: "get_vocabulary", arguments: {} }))

    assert_response :success
    result = JSON.parse(@response.body)["result"]
    assert_not result["isError"]
    payload = JSON.parse(result["content"].first["text"])
    assert_equal "Hello", payload["items"].first["word"]
    assert_equal "Hola", payload["items"].first["translation"]
  end

  test "calls get_courses with language" do
    mcp_post(rpc("tools/call", { name: "get_courses", arguments: { language: "es" } }))

    assert_response :success
    result = JSON.parse(@response.body)["result"]
    assert_not result["isError"]
    payload = JSON.parse(result["content"].first["text"])
    assert_equal [ "mcp-spanish-songs" ], payload["items"].map { |i| i["slug"] }
  end

  test "reports unknown language as tool error" do
    mcp_post(rpc("tools/call", { name: "get_courses", arguments: { language: "zz" } }))

    assert_response :success
    result = JSON.parse(@response.body)["result"]
    assert result["isError"]
  end

  test "enforces scopes per tool" do
    narrow = create_access_token(@user, scopes: "courses:read")

    mcp_post(rpc("tools/call", { name: "get_vocabulary", arguments: {} }), token: narrow)

    assert_response :success
    result = JSON.parse(@response.body)["result"]
    assert result["isError"]
    assert_includes result["content"].first["text"], "vocabulary:read"
  end
end
