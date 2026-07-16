require "test_helper"

class CreateSongAddTokenTranslationsTest < ActiveSupport::TestCase
  # The verse that actually broke in production: 67 words, repeated, so that a
  # blind 200-word slice lands five words into the final "Corazón que es lo
  # único que tengo".
  VERSE = [
    "Gran espíritu, gran abuelo, gran abuela",
    "Como soy me presento ante ti",
    "Como soy te pido bendiciones",
    "Y agradezco el corazón que has puesto en mí",
    "Cuando vengo, no más vengo, no más vengo",
    "Gran espíritu, sabrás a lo que vengo",
    "A entregar mi corazón, mi corazón",
    "Corazón que es lo único que tengo",
    "A entregar mi corazón, mi corazón",
    "Corazón que es lo único que tengo"
  ].freeze

  setup do
    @progress = CreateSongProgress.new(
      youtubeurl: "https://example.com/test",
      clip_language: "Spanish",
      translation_language: "English"
    )
    stub_renderer!
  end

  test "chunks never split a phrase across two LLM calls" do
    @progress.data = { "phrases" => phrases(VERSE * 4) } # 268 words -> >1 chunk
    fake_chat = EchoChat.new

    with_fake_chat(fake_chat) { @progress.add_token_translation }

    assert_operator fake_chat.chunks.length, :>, 1, "expected the song to be split"

    # Every chunk must start and end on a phrase boundary. Comparing cumulative
    # word offsets is the direct way to say that: each chunk boundary has to
    # coincide with the end of some phrase.
    phrase_boundaries = word_counts(VERSE * 4).each_with_object([ 0 ]) { |n, acc| acc << acc.last + n }
    chunk_boundaries = fake_chat.chunks.each_with_object([ 0 ]) { |c, acc| acc << acc.last + c.length }

    assert_equal [], chunk_boundaries - phrase_boundaries,
      "chunk boundaries #{chunk_boundaries} fall mid-phrase (phrase ends at #{phrase_boundaries})"
  end

  test "no chunk exceeds the word cap" do
    @progress.data = { "phrases" => phrases(VERSE * 4) }
    fake_chat = EchoChat.new

    with_fake_chat(fake_chat) { @progress.add_token_translation }

    cap = CreateSong::AddTokenTranslations::WORDS_PER_CHUNK
    fake_chat.chunks.each { |chunk| assert_operator chunk.length, :<=, cap }
  end

  test "translations land on the right word across chunk boundaries" do
    @progress.data = { "phrases" => phrases(VERSE * 4) }

    with_fake_chat(EchoChat.new) { @progress.add_token_translation }

    words = @progress.data["phrases"].flat_map { |p| p["words"] }
    assert_equal 268, words.length
    words.each do |word|
      assert_equal "T:#{word["text"]}", word["translation"]
    end
  end

  test "a phrase longer than the cap still gets translated, in a chunk of its own" do
    long_phrase = (1..250).map { |n| "palabra#{n}" }.join(" ")
    @progress.data = { "phrases" => phrases([ "Corto aquí", long_phrase, "Y corto aquí" ]) }
    fake_chat = EchoChat.new

    with_fake_chat(fake_chat) { @progress.add_token_translation }

    assert_equal [ 2, 250, 3 ], fake_chat.chunks.map(&:length)
    assert_equal "T:palabra250", @progress.data["phrases"][1]["words"].last["translation"]
  end

  test "a song small enough for one call makes exactly one call" do
    @progress.data = { "phrases" => phrases(VERSE) } # 67 words
    fake_chat = EchoChat.new

    with_fake_chat(fake_chat) { @progress.add_token_translation }

    assert_equal 1, fake_chat.chunks.length
    assert_equal 67, fake_chat.chunks.first.length
  end

  test "phrases with no words are skipped" do
    @progress.data = { "phrases" => [ { "words" => [] }, *phrases([ "Hola mundo" ]) ] }
    fake_chat = EchoChat.new

    with_fake_chat(fake_chat) { @progress.add_token_translation }

    assert_equal [ 2 ], fake_chat.chunks.map(&:length)
    assert_equal "T:mundo", @progress.data["phrases"][1]["words"].last["translation"]
  end

  test "an empty song saves without calling the model" do
    @progress.data = { "phrases" => [] }
    fake_chat = EchoChat.new

    with_fake_chat(fake_chat) { @progress.add_token_translation }

    assert_equal 0, fake_chat.chunks.length
  end

  private

  def word_counts(texts) = texts.map { |t| t.split.length }

  # Build the phrases/words shape add_token_translation reads.
  def phrases(texts)
    texts.map do |text|
      { "text_l1" => text, "words" => text.split.map { |w| { "text" => w } } }
    end
  end

  def with_fake_chat(fake_chat, &block)
    original_new = TracedChat.method(:new)
    TracedChat.define_singleton_method(:new) do |**kwargs|
      if kwargs[:span_name].to_s == "add_token_translations"
        fake_chat
      else
        original_new.call(**kwargs)
      end
    end
    block.call
  ensure
    TracedChat.define_singleton_method(:new, original_new) rescue nil
  end

  def stub_renderer!
    ApplicationController.renderer.define_singleton_method(:render) { |*args, **kwargs| "Test instructions" }
  end

  # A well-behaved model: echoes each input line back with a marker translation
  # appended, and translates exactly the lines it was asked about. Records each
  # chunk's lines so tests can assert on how the work was split. Shared across
  # concurrent async tasks, hence the mutex.
  class EchoChat
    def initialize
      @chunks = []
      @mutex = Mutex.new
    end

    def chunks = @mutex.synchronize { @chunks.dup }

    def with_instructions(*) = self

    def add_message(role:, content:)
      @lines = content.lines.map(&:strip)
      @mutex.synchronize { @chunks << @lines }
      self
    end

    def complete
      body = @lines.map { |line| "#{line} T:#{line.split(" ").first}" }.join("\n")
      FakeResponse.new(body)
    end
  end

  FakeResponse = Struct.new(:content)
end
