require "test_helper"
require "rake"

class MigrateLegacySimilarSoundsTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("data:migrate_legacy_similar_sounds")
    @task = Rake::Task["data:migrate_legacy_similar_sounds"]
    @language = languages(:english)
    @medium = Medium.create!(url: "https://example.com/legacy-sounds", language: @language)
  end

  teardown do
    ENV.delete("DRY_RUN")
    ENV.delete("PHRASE_TOKEN_ID")
  end

  test "migrates character-indexed multiword token sounds and clears the legacy array" do
    phrase = Phrase.create!(medium: @medium, l1: @language, text_l1: "stay by my side", timestamp: "00:01")
    token = phrase.phrase_tokens.create!(
      l1_start_index: 5, l1_end_index: 9, index_type: :character_index,
      similar_sound: [ "buy me", "find me" ]
    )

    invoke_for(token)

    assert_equal [], token.reload.similar_sound
    assert_equal [
      [ 1, 2, "buy me" ],
      [ 1, 2, "find me" ]
    ], phrase.similar_sounds.order(:replacement_text).pluck(:start_word_index, :end_word_index, :replacement_text)
  end

  test "uses raw indexes for word-indexed tokens and does not duplicate existing rows" do
    phrase = Phrase.create!(medium: @medium, l1: @language, text_l1: "stay by my side", timestamp: "00:01")
    token = phrase.phrase_tokens.create!(
      l1_start_index: 1, l1_end_index: 2, index_type: :word_index,
      similar_sound: [ "buy me", "find me" ]
    )
    phrase.similar_sounds.create!(start_word_index: 1, end_word_index: 2, replacement_text: "buy me")

    invoke_for(token)

    assert_equal 2, phrase.similar_sounds.count
    assert_equal 1, phrase.similar_sounds.where(replacement_text: "buy me").count
  end

  test "dry run reports work without changing data" do
    phrase = Phrase.create!(medium: @medium, l1: @language, text_l1: "stay here", timestamp: "00:01")
    token = phrase.phrase_tokens.create!(
      l1_start_index: 1, l1_end_index: 1, index_type: :word_index,
      similar_sound: [ "near" ]
    )
    ENV["DRY_RUN"] = "1"

    output = capture_io { invoke_for(token) }.first

    assert_includes output, "Dry run complete"
    assert_equal [ "near" ], token.reload.similar_sound
    assert_empty phrase.similar_sounds
  end

  private

  def invoke_for(token)
    ENV["PHRASE_TOKEN_ID"] = token.id.to_s
    @task.reenable
    @task.invoke
  end
end
