require "test_helper"

class VocabularyReviewScheduleTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "schedule@example.com", password: "password123", confirmed_at: Time.zone.now)
    @entry = PhraseTokenUser.create_custom!(user: @user, sentence: "no queda tiempo", language: languages(:spanish),
      token_range: 2..2, translation: "time", translation_language: languages(:english))
  end

  def review
    Lesson.create!(user: @user, review_language: languages(:spanish), review_build_status: :started)
  end

  test "new words are due immediately and successful recall grows the interval up to thirty days" do
    assert @entry.familiarity_new_word?
    assert @entry.review_due?

    [ 1, 3, 7, 14, 30, 30 ].each do |days|
      travel_to((@entry.next_review_at || Time.zone.now) + 1.second) do
        lesson = review
        @entry.record_recall!(lesson: lesson, remembered: true)
        assert_equal Time.zone.now + days.days, @entry.next_review_at
        assert_not @entry.review_due?
      end
    end
    assert @entry.familiarity_mastered?
  end

  test "forgetting resets familiarity and schedules a retry in ten minutes" do
    @entry.update!(familiarity: :confident)
    travel_to(Time.zone.now) do
      @entry.record_recall!(lesson: review, remembered: false)
      assert @entry.familiarity_new_word?
      assert_equal 10.minutes.from_now, @entry.next_review_at
    end
  end

  test "duplicate recall submissions do not advance or reset a word twice" do
    lesson = review
    @entry.record_recall!(lesson: lesson, remembered: true)
    assert @entry.familiarity_learning?
    due_at = @entry.next_review_at

    @entry.record_recall!(lesson: lesson, remembered: true)
    @entry.record_recall!(lesson: lesson, remembered: false)
    assert @entry.familiarity_learning?
    assert_equal due_at, @entry.next_review_at
  end

  test "a prebuilt session can schedule a word that became due before it was started" do
    @entry.set_familiarity!("learning")
    lesson = Lesson.create!(user: @user, review_language: languages(:spanish), review_build_status: :pending)
    travel_to(@entry.next_review_at + 1.minute) do
      lesson.update!(review_build_status: :started, review_started_at: Time.zone.now)
      @entry.record_recall!(lesson: lesson, remembered: true)
      assert @entry.familiarity_familiar?
      assert_equal 3.days.from_now, @entry.next_review_at
    end
  end

  test "manual familiarity sets the interval and new resets the word to due now" do
    travel_to(Time.zone.now) do
      @entry.set_familiarity!("strong")
      assert_equal 14.days.from_now, @entry.next_review_at
      assert_nil @entry.last_review_lesson_id
      @entry.set_familiarity!("new_word")
      assert @entry.review_due?
      assert_equal Time.zone.now, @entry.next_review_at
    end
    assert_raises(ArgumentError) { @entry.set_familiarity!("invalid") }
  end

  test "a started session cannot overwrite a newer manual familiarity choice" do
    lesson = review
    travel_to(lesson.created_at + 1.minute) do
      @entry.set_familiarity!("mastered")
      due_at = @entry.next_review_at
      @entry.record_recall!(lesson: lesson, remembered: false)
      assert @entry.familiarity_mastered?
      assert_equal due_at, @entry.next_review_at
    end
  end

  test "a stale session cannot overwrite another session's result" do
    older = review
    newer = review
    @entry.record_recall!(lesson: newer, remembered: true)
    @entry.record_recall!(lesson: older, remembered: false)
    assert @entry.familiarity_learning?
    assert_equal newer.id, @entry.last_review_lesson_id
  end

  test "paused and early extra-practice words keep their schedule" do
    @entry.set_familiarity!("familiar")
    @entry.record_recall!(lesson: review, remembered: true)
    assert @entry.familiarity_familiar?
    @entry.set_familiarity!("new_word")
    @entry.update!(practicing: false)
    @entry.record_recall!(lesson: review, remembered: true)
    assert @entry.familiarity_new_word?
    assert_not @entry.review_due?
    assert_not_includes PhraseTokenUser.due, @entry
  end
end
