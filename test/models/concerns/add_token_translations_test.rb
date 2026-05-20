require "test_helper"

class AddTokenTranslationsTest < ActiveSupport::TestCase
  setup do
    @phrases = [
      { "id" => "p1", "text_l1" => "Bref, quand je dois prendre rendez-vous", "text_l2" => "So, when I have to make a date" },
      { "id" => "p2", "text_l1" => "avec une fille,", "text_l2" => "with a girl," },
      { "id" => "p3", "text_l1" => "j'attends toujours trois jours", "text_l2" => "I always wait three days" },
      { "id" => "p4", "text_l1" => "avant de lui envoyer un texto", "text_l2" => "before texting her" },
      { "id" => "p5", "text_l1" => "pour montrer que je suis un gars détaché.", "text_l2" => "to show I'm a chill guy." },
      { "id" => "p6", "text_l1" => "Entre-temps, je tape son nom", "text_l2" => "Meanwhile, I type her name" },
      { "id" => "p7", "text_l1" => "et son prénom dans Google", "text_l2" => "and surname into Google" },
    ]

    @progress = CreateSongProgress.new(
      youtubeurl: "https://example.com/test",
      clip_language: "French",
      translation_language: "English",
      data: { "phrases" => @phrases }
    )

    @mock_responses = {
      "Bref, quand je dois prendre rendez-vous => So, when I have to make a date" =>
        "[Bref], quand je dois prendre rendez-vous => [So], when I have to make a date\n" \
        "Bref, [quand] je dois prendre rendez-vous => So, [when] I have to make a date\n" \
        "Bref, quand [je] dois prendre rendez-vous => So, when [I] have to make a date\n" \
        "Bref, quand je [dois] prendre rendez-vous => So, when I [have to] make a date\n" \
        "Bref, quand je dois [prendre] rendez-vous => So, when I have to [make] a date\n" \
        "Bref, quand je dois prendre [rendez-vous] => So, when I have to make [a date]",

      "avec une fille, => with a girl," =>
        "[avec] une fille, => [with] a girl,\n" \
        "avec [une] fille, => with [a] girl,\n" \
        "avec une [fille], => with a [girl],",

      "j'attends toujours trois jours => I always wait three days" =>
        "[j']attends toujours trois jours => [I] always wait three days\n" \
        "j'[attends] toujours trois jours => I always [wait] three days\n" \
        "j'attends [toujours] trois jours => I [always] wait three days\n" \
        "j'attends toujours [trois] jours => I always wait [three] days\n" \
        "j'attends toujours trois [jours] => I always wait three [days]",

      "avant de lui envoyer un texto => before texting her" =>
        "[avant] de lui envoyer un texto => [before] texting her\n" \
        "avant de [lui] envoyer un texto => before texting [her]\n" \
        "avant de lui [envoyer un texto] => [texting] her",

      "pour montrer que je suis un gars détaché. => to show I'm a chill guy." =>
        "[pour] montrer que je suis un gars détaché. => [to] show I'm a chill guy.\n" \
        "pour [montrer] que je suis un gars détaché. => to [show] I'm a chill guy.\n" \
        "pour montrer que [je] suis un gars détaché. => to show [I]'m a chill guy.\n" \
        "pour montrer que je [suis] un gars détaché. => to show I['m] a chill guy.\n" \
        "pour montrer que je suis [un] gars détaché. => to show I'm [a] chill guy.\n" \
        "pour montrer que je suis un [gars] détaché. => to show I'm a chill [guy].\n" \
        "pour montrer que je suis un gars [détaché]. => to show I'm a [chill] guy.",

      "Entre-temps, je tape son nom => Meanwhile, I type her name" =>
        "[Entre-temps], je tape son nom => [Meanwhile], I type her name\n" \
        "Entre-temps, [je] tape son nom => Meanwhile, [I] type her name\n" \
        "Entre-temps, je [tape] son nom => Meanwhile, I [type] her name\n" \
        "Entre-temps, je tape [son] nom => Meanwhile, I [her] name\n" \
        "Entre-temps, je tape son [nom] => Meanwhile, I type her [name]",

      "et son prénom dans Google => and surname into Google" =>
        "[et] son prénom dans Google => [and] surname into Google\n" \
        "et [son] prénom dans Google => and [surname] into Google\n" \
        "et son [prénom] dans Google => [surname] into Google\n" \
        "et son prénom [dans] Google => and surname [into] Google\n" \
        "et son prénom dans [Google] => and surname into [Google]",
    }
  end

  test "produces correct token translations for all phrases" do
    stub_renderer!
    stub_fetch_translation!(mock_fetch(@mock_responses))

    @progress.add_token_translation

    result = @progress.data["phrases_with_token_translations"]
    assert_not_nil result

    # Verify each phrase's block is present and separated by double-newlines
    assert_match(/\[Bref\], quand je dois prendre rendez-vous/, result)
    assert_match(/avec une \[fille\]/, result)
    assert_match(/j'attends toujours \[trois\] jours/, result)
    assert_match(/\[avant\] de lui envoyer un texto/, result)
    assert_match(/pour montrer que je suis un \[gars\] détaché/, result)
    assert_match(/\[Entre-temps\]/, result)
    assert_match(/et son prénom dans \[Google\]/, result)

    # Verify block separation
    blocks = result.split(/\n\n/)
    assert_equal 7, blocks.size, "Expected 7 blocks, one per phrase"
  end

  test "limits concurrent requests to max_concurrency of 3" do
    concurrent = 0
    max_concurrent = 0
    mutex = Mutex.new
    delay = 0.05 # Simulate API latency

    fetch_stub = ->(instructions, block, max_retries) {
      mutex.synchronize do
        concurrent += 1
        max_concurrent = [max_concurrent, concurrent].max
      end
      sleep(delay)
      mutex.synchronize { concurrent -= 1 }

      key = block.join.strip
      @mock_responses.fetch(key)
    }

    stub_renderer!
    stub_fetch_translation!(fetch_stub)

    @progress.add_token_translation

    assert max_concurrent <= 3,
      "Max concurrent requests was #{max_concurrent}, expected <= 3"
    assert_equal 3, max_concurrent,
      "With 7 phrases and semaphore=3, should have reached concurrency limit of 3, got #{max_concurrent}"
  end

  test "preserves block order in output" do
    stub_renderer!
    stub_fetch_translation!(mock_fetch(@mock_responses))

    @progress.add_token_translation

    result = @progress.data["phrases_with_token_translations"]
    blocks = result.split(/\n\n/)

    assert blocks[0].start_with?("[Bref]"), "First block should be phrase 1, got: #{blocks[0][0..40]}"
    assert blocks[1].start_with?("[avec]"), "Second block should be phrase 2, got: #{blocks[1][0..40]}"
    assert blocks[2].include?("[j']attends"), "Third block should be phrase 3"
  end

  private

  def stub_renderer!
    renderer = ApplicationController.renderer
    renderer.define_singleton_method(:render) { |*args, **kwargs| "Test instructions" }
  end

  def stub_fetch_translation!(callable)
    @progress.define_singleton_method(:fetch_translation) do |instructions, block, max_retries|
      callable.call(instructions, block, max_retries)
    end
  end

  def mock_fetch(responses)
    ->(instructions, block, max_retries) {
      key = block.join.strip
      responses.fetch(key) { raise "No mock response for: #{key.inspect}" }
    }
  end
end
