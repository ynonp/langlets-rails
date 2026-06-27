require "test_helper"

class RateLessonsTest < ActiveSupport::TestCase
  setup do
    @lessons = <<~LESSONS.strip
      # The Apateu Chant
      00:06.50 Apateu, apateu
      00:11.10 Uh, uh-huh, uh-huh

      # The Invitation
      00:32.00 Don't you want me like I want you, baby?
      00:35.20 Don't you need me like I need you now?
    LESSONS

    @progress = CreateSongProgress.new(
      youtubeurl: "https://example.com/test",
      clip_language: "English",
      translation_language: "Hebrew",
      data: { "lessons" => @lessons }
    )
  end

  test "parse_ratings reads a bare JSON array" do
    ratings = @progress.send(:parse_ratings,
      '[{"index":1,"title":"The Apateu Chant","score":1,"reason":"nonsense"},' \
      '{"index":2,"title":"The Invitation","score":5,"reason":"real phrases"}]')

    assert_equal 2, ratings.size
    assert_equal({ "index" => 1, "title" => "The Apateu Chant", "score" => 1, "reason" => "nonsense" }, ratings.first)
    assert_equal 5, ratings.second["score"]
  end

  test "parse_ratings tolerates markdown fences and surrounding prose" do
    content = "Here are the ratings:\n```json\n[{\"index\":1,\"title\":\"X\",\"score\":3,\"reason\":\"ok\"}]\n```\nDone."
    ratings = @progress.send(:parse_ratings, content)

    assert_equal 1, ratings.size
    assert_equal 3, ratings.first["score"]
  end

  test "parse_ratings returns empty array on unparseable content" do
    assert_equal [], @progress.send(:parse_ratings, "no json here")
  end

  test "rate_lessons stores parsed ratings from the LLM response" do
    stub_renderer!
    stub_chat_response!(
      '[{"index":1,"title":"The Apateu Chant","score":1,"reason":"nonsense"},' \
      '{"index":2,"title":"The Invitation","score":5,"reason":"real phrases"}]'
    )

    @progress.define_singleton_method(:save!) { true }
    @progress.rate_lessons

    assert @progress.lessons_rated?
    assert_equal [ 1, 5 ], @progress.data["lesson_ratings"].map { |r| r["score"] }
  end

  test "rate_lessons is a no-op when there are no lessons" do
    @progress.data["lessons"] = nil
    assert_nil @progress.rate_lessons
    assert_not @progress.lessons_rated?
  end

  private

  def stub_renderer!
    renderer = ApplicationController.renderer
    renderer.define_singleton_method(:render) { |*args, **kwargs| "Test instructions" }
  end

  def stub_chat_response!(content)
    response = Struct.new(:content, :role).new(content, "assistant")
    fake_chat = Object.new
    fake_chat.define_singleton_method(:with_temperature) { |_| self }
    fake_chat.define_singleton_method(:with_instructions) { |_| self }
    fake_chat.define_singleton_method(:add_message) { |**_| self }
    fake_chat.define_singleton_method(:complete) { response }
    TracedChat.define_singleton_method(:new) { |*args, **kwargs| fake_chat }
  end

  teardown do
    TracedChat.singleton_class.send(:remove_method, :new) if TracedChat.singleton_class.method_defined?(:new) && TracedChat.singleton_methods.include?(:new)
  rescue NameError
    # method was not stubbed
  end
end
