require "test_helper"

class CourseCorrectionTest < ActiveJob::TestCase
  def setup
    @english = languages(:english)
    @hebrew = languages(:hebrew)
    @user = User.create!(
      email: "course-correction@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @medium = Medium.create!(url: "https://example.com/course-correction", language: @english)
    @course = Course.create!(
      name: "Course correction",
      slug: "course-correction",
      main_media_url: @medium.url,
      user: @user
    )
    @lesson = Lesson.create!(course: @course, medium: @medium, user: @user, name: "Lesson")
  end

  test "correct_text finds a phrase after the transcript offset, creates tokens, and restores activity token counts" do
    first_phrase = Phrase.create!(medium: @medium, l1: @english, text_l1: "wrong elsewhere", timestamp: "00:01")
    phrase = Phrase.create!(medium: @medium, l1: @english, text_l1: "a wrong phrase", timestamp: "00:02")
    deleted = phrase.phrase_tokens.create!(
      l1_start_index: 2,
      l1_end_index: 6,
      index_type: :character_index
    )
    activity = Activities::FlashcardActivity.create!(lesson: @lesson, user: @user)
    activity.activity_phrase_tokens.create!(phrase_token: deleted)
    offset = first_phrase.text_l1.length + 1

    affected = @course.correct_text(
      "wrong",
      "right words",
      tokens: [ "right", { "en" => "correct", "he" => "נכון" },
                "words", { "en" => "words", "he" => "מילים" } ],
      offset: offset
    )

    assert_equal "wrong elsewhere", first_phrase.reload.text_l1
    assert_equal "a right words phrase", phrase.reload.text_l1
    assert_equal({ activity => 1 }, affected)
    assert_equal 1, activity.activity_phrase_tokens.reload.count
    assert_includes phrase.phrase_tokens.where.not(id: deleted.id).ids,
      activity.activity_phrase_tokens.first.phrase_token_id
  end
end
