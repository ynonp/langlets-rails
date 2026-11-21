require "test_helper"

class DictionaryLookupTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @user = User.create!(email: "dictionary@example.com", password: "password123", confirmed_at: Time.zone.now)
    @arabic = languages(:arabic)
    @hebrew = languages(:hebrew)
  end

  def ready_lookup(**attributes)
    DictionaryLookup.insert_all!([ {
      user_id: @user.id, query: "מנהיג", target_language_id: @arabic.id, native_language_id: @hebrew.id,
      status: DictionaryLookup.statuses[:ready], illustration_status: DictionaryLookup.illustration_statuses[:drawn],
      direction: "to_target", detected_language: "he", headword: "زعيم", translation: "מנהיג",
      examples: [
        { "sentence" => "اختار الحزب الزعيم الجديد.", "highlight" => "الزعيم", "translation" => "המפלגה בחרה את המנהיג החדש." },
        { "sentence" => "هو  زعيم سياسي.", "highlight" => "زعيم", "translation" => "הוא מנהיג פוליטי." }
      ],
      created_at: Time.zone.now, updated_at: Time.zone.now
    }.merge(attributes) ])
    @user.dictionary_lookups.order(:id).last
  end

  test "creating a lookup queues its generation" do
    assert_enqueued_with(job: GenerateDictionaryEntryJob) do
      @user.dictionary_lookups.create!(query: "  leader ", target_language: @arabic, native_language: @hebrew)
    end
    assert_equal "leader", @user.dictionary_lookups.last.query
  end

  test "the target and native languages must differ" do
    lookup = @user.dictionary_lookups.build(query: "x", target_language: @hebrew, native_language: @hebrew)
    assert_not lookup.valid?
  end

  test "example rows split each sentence around its highlight and normalize whitespace" do
    rows = ready_lookup.example_rows

    assert_equal "هو زعيم سياسي.", rows.second[:sentence]
    assert_equal [ "هو ", "زعيم", " سياسي." ], rows.second.values_at(:before, :mark, :after)
  end

  test "an example whose highlight is missing stays whole and unmarked" do
    lookup = ready_lookup(examples: [ { "sentence" => "جملة", "highlight" => "غير موجود", "translation" => "" } ])

    assert_equal [ "جملة", "", "" ], lookup.example_rows.first.values_at(:before, :mark, :after)
  end

  test "saving prefers an example using the headword exactly and stores both translations" do
    lookup = ready_lookup

    saved = nil
    assert_difference -> { @user.phrase_token_users.count }, 1 do
      # The example's own translation is stored; no model call is queued for it.
      assert_no_enqueued_jobs(only: TranslateCustomPhraseJob) { saved = lookup.save_to_vocabulary! }
    end

    assert_equal "زعيم", saved.word
    assert_equal "מנהיג", saved.translation
    assert_equal @hebrew, saved.language
    assert_equal @arabic, saved.phrase.l1
    assert_equal "هو زعيم سياسي.", saved.phrase.text_l1
    assert saved.phrase.custom?
    assert_equal "הוא מנהיג פוליטי.", saved.phrase.phrase_translations.find_by!(language: @hebrew).text
    assert_equal saved.phrase_token, lookup.reload.phrase_token
    assert lookup.saved?
  end

  test "saving twice keeps one vocabulary entry" do
    lookup = ready_lookup
    lookup.save_to_vocabulary!

    assert_no_difference -> { @user.phrase_token_users.count } do
      lookup.save_to_vocabulary!
    end
  end

  test "without a usable example the headword is saved as its own phrase" do
    lookup = ready_lookup(examples: [])

    saved = lookup.save_to_vocabulary!

    assert_equal "زعيم", saved.word
    assert_equal "زعيم", saved.phrase.text_l1
  end

  test "a lookup that is not ready cannot be saved" do
    lookup = ready_lookup(status: DictionaryLookup.statuses[:generating])

    assert_raises(ActiveRecord::RecordInvalid) { lookup.save_to_vocabulary! }
  end

  test "pending covers generation and drawing, and a lost generation turns stale" do
    assert ready_lookup(status: DictionaryLookup.statuses[:generating]).pending?
    assert ready_lookup(illustration_status: DictionaryLookup.illustration_statuses[:drawing]).pending?

    stale = ready_lookup(status: DictionaryLookup.statuses[:generating], created_at: 5.minutes.ago)
    assert stale.failed_or_stale?
    assert_not stale.pending?
  end

  test "the source language follows the stored direction" do
    assert_equal @hebrew, ready_lookup.source_language
    assert_equal @arabic, ready_lookup(direction: "to_native", detected_language: "ar-JO").source_language
    assert_equal @hebrew, ready_lookup(direction: "to_native").result_language
  end
end
