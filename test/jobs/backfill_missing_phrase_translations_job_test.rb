require "test_helper"

class BackfillMissingPhraseTranslationsJobTest < ActiveJob::TestCase
  setup do
    @user = User.create!(email: "phrase-backfill@example.com", password: "password123", confirmed_at: Time.zone.now)
    @english = languages(:english)
    @french = languages(:french)
    @phrase = @user.custom_phrases.create!(l1: languages(:spanish), text_l1: "No queda tiempo")
  end

  test "queues distinct missing target languages including paused words" do
    save_word(@phrase, 0, @english)
    save_word(@phrase, 1, @english)
    save_word(@phrase, 2, @french).update!(practicing: false)
    clear_enqueued_jobs

    assert_enqueued_with(job: TranslateCustomPhraseJob, args: [@phrase.id, @english.id]) do
      assert_enqueued_with(job: TranslateCustomPhraseJob, args: [@phrase.id, @french.id]) do
        assert_equal 2, BackfillMissingPhraseTranslationsJob.perform_now
      end
    end
    assert_enqueued_jobs 2, only: TranslateCustomPhraseJob
  end

  test "skips translated languages, course phrases and unsaved custom phrases" do
    save_word(@phrase, 0, @english)
    save_word(@phrase, 1, @french)
    @phrase.phrase_translations.create!(language: @english, text: "No time left")
    @user.custom_phrases.create!(l1: @phrase.l1, text_l1: "Sin palabras")
    medium = Medium.create!(url: "https://example.com/phrase-backfill", language: @phrase.l1)
    imported = medium.phrases.create!(l1: @phrase.l1, text_l1: "Otra frase")
    save_word(imported, 0, @english)
    clear_enqueued_jobs

    assert_enqueued_with(job: TranslateCustomPhraseJob, args: [@phrase.id, @french.id]) do
      assert_equal 1, BackfillMissingPhraseTranslationsJob.perform_now
    end
    assert_enqueued_jobs 1, only: TranslateCustomPhraseJob

    @phrase.phrase_translations.create!(language: @french, text: "Il ne reste plus de temps")
    clear_enqueued_jobs
    assert_no_enqueued_jobs(only: TranslateCustomPhraseJob) do
      assert_equal 0, BackfillMissingPhraseTranslationsJob.perform_now
    end
  end

  test "runs hourly in production" do
    task = YAML.safe_load_file(Rails.root.join("config/recurring.yml"))
      .dig("production", "backfill_missing_phrase_translations")
    assert_equal "BackfillMissingPhraseTranslationsJob", task.fetch("class")
    assert_equal "every hour", task.fetch("schedule")
  end

  private

  def save_word(phrase, index, language)
    token = phrase.phrase_tokens.create!(l1_start_index: index, l1_end_index: index)
    token.token_translations.create!(language: language, translation: "meaning")
    @user.phrase_token_users.create!(phrase_token: token, language: language)
  end
end
