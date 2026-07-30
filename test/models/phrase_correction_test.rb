require "test_helper"

class PhraseCorrectionTest < ActiveJob::TestCase
  def setup
    @english = languages(:english)
    @hebrew = languages(:hebrew)
    @medium = Medium.create!(url: "https://example.com/correction", language: @english)
  end

  test "correct_text replaces character-indexed text, deletes covered tokens, shifts later tokens, and reports activities" do
    phrase = create_phrase!("one bad ending")
    before = create_token!(phrase, 0, 2, :character_index)
    deleted = create_token!(phrase, 4, 6, :character_index)
    after = create_token!(phrase, 8, 13, :character_index)
    activity = create_activity_with(deleted)

    result = phrase.correct_text("bad", "wonderful")

    assert_equal "one wonderful ending", phrase.reload.text_l1
    assert_equal [ before.id, after.id ], phrase.phrase_tokens.order(:id).pluck(:id)
    assert_equal [ 14, 19 ], after.reload.attributes.values_at("l1_start_index", "l1_end_index")
    assert_equal({ activity => 1 }, result)
  end

  test "correct_text uses tokenize positions for word-indexed tokens" do
    phrase = create_phrase!("I have a bad idea")
    deleted = create_token!(phrase, 2, 3, :word_index)
    after = create_token!(phrase, 4, 4, :word_index)

    phrase.correct_text("a bad", "the truly excellent")

    assert_not PhraseToken.exists?(deleted.id)
    assert_equal [ 5, 5 ], after.reload.attributes.values_at("l1_start_index", "l1_end_index")
  end

  test "correct_text deletes every token whose range touches the changed character range" do
    phrase = create_phrase!("one very bad ending")
    before = create_token!(phrase, 0, 2, :character_index)
    overlaps_start = create_token!(phrase, 4, 9, :character_index)
    contains_change = create_token!(phrase, 4, 11, :character_index)
    overlaps_end = create_token!(phrase, 9, 14, :character_index)
    after = create_token!(phrase, 13, 18, :character_index)

    phrase.correct_text("bad", "good")

    assert_equal [ before.id, after.id ], phrase.phrase_tokens.order(:id).ids
    assert_not PhraseToken.exists?(overlaps_start.id)
    assert_not PhraseToken.exists?(contains_change.id)
    assert_not PhraseToken.exists?(overlaps_end.id)
  end

  test "correct_text deletes every token whose range touches the changed word range" do
    phrase = create_phrase!("one very bad ending")
    before = create_token!(phrase, 0, 0, :word_index)
    overlaps_start = create_token!(phrase, 1, 2, :word_index)
    contains_change = create_token!(phrase, 0, 3, :word_index)
    overlaps_end = create_token!(phrase, 2, 3, :word_index)

    phrase.correct_text("bad", "good")

    assert_equal [ before.id ], phrase.phrase_tokens.ids
    assert_not PhraseToken.exists?(overlaps_start.id)
    assert_not PhraseToken.exists?(contains_change.id)
    assert_not PhraseToken.exists?(overlaps_end.id)
  end

  test "correct_text raises without changing data when assumptions fail" do
    phrase = create_phrase!("bad and bad")
    token = create_token!(phrase, 0, 2, :character_index)

    assert_raises(ArgumentError) { phrase.correct_text("bad", "good") }
    assert_equal "bad and bad", phrase.reload.text_l1
    assert PhraseToken.exists?(token.id)
  end

  test "create_token chooses the first uncovered duplicate and creates translations" do
    phrase = create_phrase!("home then home")
    create_token!(phrase, 0, 3, :character_index)

    token = phrase.create_token("home", en: "a home", he: "בית")

    assert_equal [ 10, 13 ], token.attributes.values_at("l1_start_index", "l1_end_index")
    assert_equal "character_index", token.index_type
    assert_equal({ "en" => "a home", "he" => "בית" },
      token.token_translations.joins(:language).pluck("languages.iso_name", :translation).to_h)
  end

  private

  def create_phrase!(text)
    Phrase.create!(medium: @medium, l1: @english, text_l1: text, timestamp: "00:01")
  end

  def create_token!(phrase, start_index, end_index, index_type)
    phrase.phrase_tokens.create!(
      l1_start_index: start_index,
      l1_end_index: end_index,
      index_type: index_type
    )
  end

  def create_activity_with(token)
    user = User.create!(email: "correction-#{SecureRandom.hex(4)}@example.com", password: "password123", confirmed_at: Time.zone.now)
    course = Course.create!(name: "Correction", slug: "correction-#{SecureRandom.hex(4)}", main_media_url: @medium.url, user: user)
    lesson = Lesson.create!(course: course, medium: @medium, user: user, name: "Lesson")
    activity = Activities::FlashcardActivity.create!(lesson: lesson, user: user)
    activity.activity_phrase_tokens.create!(phrase_token: token)
    activity
  end
end
