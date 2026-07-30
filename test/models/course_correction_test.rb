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
    @course.course_translations.create!(language: @hebrew, name: "Course correction", status: :ready)
    @lesson = Lesson.create!(course: @course, medium: @medium, user: @user, name: "Lesson")
  end

  test "correct_text updates every exact phrase, creates tokens and translations, restores activities, and rebuilds progress" do
    first_phrase = Phrase.create!(medium: @medium, l1: @english, text_l1: "red one blue two", timestamp: "00:01")
    second_phrase = Phrase.create!(medium: @medium, l1: @english, text_l1: "red one blue two", timestamp: "00:02")
    first_deleted = first_phrase.phrase_tokens.create!(
      l1_start_index: 0,
      l1_end_index: 2,
      index_type: :character_index
    )
    first_preserved = first_phrase.phrase_tokens.create!(
      l1_start_index: 8,
      l1_end_index: 11,
      index_type: :character_index
    )
    second_phrase.phrase_tokens.create!(
      l1_start_index: 0,
      l1_end_index: 2,
      index_type: :character_index
    )
    [ first_phrase, second_phrase ].each do |phrase|
      phrase.phrase_translations.create!(language: @hebrew, text: "old translation")
    end
    activity = Activities::FlashcardActivity.create!(lesson: @lesson, user: @user)
    activity.activity_phrase_tokens.create!(phrase_token: first_deleted)
    progress = CreateSongProgress.create!(
      youtubeurl: @course.main_media_url,
      clip_language: @english.english_name,
      translation_language: @hebrew.english_name,
      data: {
        "format_version" => CreateSongProgress::DataFormat::VERSION,
        "phrases" => [
          { "text_l1" => "stale first phrase" }
        ]
      }
    )
    @course.update!(create_song_progress: progress)

    affected = @course.correct_text(
      "red one blue two",
      "scarlet one blue seven",
      tokens: [ "scarlet", { en: "scarlet" },
                "seven", { en: "seven" } ],
      translations: { he: "תרגום חדש" }
    )

    assert_equal "scarlet one blue seven", first_phrase.reload.text_l1
    assert_equal "scarlet one blue seven", second_phrase.reload.text_l1
    assert_equal "תרגום חדש", first_phrase.phrase_translations.find_by!(language: @hebrew).text
    assert_equal "תרגום חדש", second_phrase.phrase_translations.find_by!(language: @hebrew).text
    assert_equal({ activity => 1 }, affected)
    assert_equal 1, activity.activity_phrase_tokens.reload.count
    assert_includes first_phrase.phrase_tokens.where.not(id: first_deleted.id).ids,
      activity.activity_phrase_tokens.first.phrase_token_id
    assert_equal [ 12, 15 ],
      first_preserved.reload.attributes.values_at("l1_start_index", "l1_end_index")
    assert_equal [ "scarlet one blue seven", "scarlet one blue seven" ],
      progress.reload.data["phrases"].pluck("text_l1")
    assert_equal [ "scarlet", "blue", "seven" ],
      progress.data.dig("phrases", 0, "words").pluck("text")
    assert_equal "תרגום חדש",
      progress.data.dig("translations", "he", "phrases", 0, "text")
  end

  test "correct_text rolls back all matching phrases when a requested token is invalid" do
    phrases = [
      Phrase.create!(medium: @medium, l1: @english, text_l1: "old phrase", timestamp: "00:01"),
      Phrase.create!(medium: @medium, l1: @english, text_l1: "old phrase", timestamp: "00:02")
    ]
    phrases.each do |phrase|
      phrase.phrase_tokens.create!(l1_start_index: 0, l1_end_index: 2, index_type: :character_index)
    end

    assert_raises(ArgumentError) do
      @course.correct_text(
        "old phrase",
        "new phrase",
        tokens: [ "missing", { en: "missing" } ],
        translations: { en: "new phrase" }
      )
    end

    assert_equal [ "old phrase", "old phrase" ], phrases.map { |phrase| phrase.reload.text_l1 }
  end
end
