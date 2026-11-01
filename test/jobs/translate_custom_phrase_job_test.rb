require "test_helper"

class TranslateCustomPhraseJobTest < ActiveJob::TestCase
  setup do
    @user = User.create!(email: "sentence-translation@example.com", password: "password123", confirmed_at: Time.zone.now)
    @phrase = @user.custom_phrases.create!(l1: languages(:spanish), text_l1: "No queda tiempo.")
    @language = languages(:english)
  end

  test "custom saves enqueue missing translations including repeated saves" do
    arguments = { user: @user, sentence: @phrase.text_l1, language: @phrase.l1,
                  translation_language: @language, translation: "time", token_range: [2, 2] }
    2.times do
      assert_enqueued_with(job: TranslateCustomPhraseJob, args: [@phrase.id, @language.id]) do
        PhraseTokenUser.create_custom!(**arguments)
      end
    end
    @phrase.phrase_translations.create!(language: @language, text: "There is no time left.")
    assert_no_enqueued_jobs(only: TranslateCustomPhraseJob) do
      PhraseTokenUser.create_custom!(**arguments)
    end
  end

  test "translates and preserves an existing translation on retry" do
    job = TranslateCustomPhraseJob.new
    job.stub(:translate, "There is no time left.") { job.perform(@phrase.id, @language.id) }
    job.stub(:translate, ->(*) { flunk "Should not translate twice" }) { job.perform(@phrase.id, @language.id) }
    assert_equal "There is no time left.", @phrase.phrase_translations.find_by!(language: @language).text
  end

  test "does not overwrite a translation created during the model request" do
    job = TranslateCustomPhraseJob.new
    job.stub(:translate, ->(*) {
      @phrase.phrase_translations.create!(language: @language, text: "Manual translation")
      "Generated translation"
    }) { job.perform(@phrase.id, @language.id) }
    assert_equal "Manual translation", @phrase.phrase_translations.find_by!(language: @language).text
  end

  test "empty model output retries without persisting a translation" do
    job = TranslateCustomPhraseJob.new
    job.arguments = [@phrase.id, @language.id]
    job.stub(:translate, " ") do
      assert_enqueued_with(job: TranslateCustomPhraseJob) do
        job.perform_now
      end
    end
    assert_empty @phrase.phrase_translations
  end

  test "calls the supported provider model and persists its response" do
    chat = Minitest::Mock.new
    chat.expect(:with_temperature, chat, [0.2])
    chat.expect(:with_params, chat, reasoning_effort: "none")
    chat.expect(:with_instructions, chat) do |instructions|
      instructions.include?("Spanish") && instructions.include?("English")
    end
    chat.expect(:ask, Struct.new(:content).new("There is no time left."), [@phrase.text_l1])
    factory = ->(**options) {
      assert_equal({model: "deepseek-v4-pro:cloud", provider: :ollama, assume_model_exists: true}, options)
      chat
    }
    RubyLLM.stub(:chat, factory) do
      TranslateCustomPhraseJob.perform_now(@phrase.id, @language.id)
    end
    chat.verify
    assert_equal "There is no time left.", @phrase.phrase_translations.find_by!(language: @language).text
  end

  test "enqueueing waits for commit" do
    assert TranslateCustomPhraseJob.enqueue_after_transaction_commit
  end
end
