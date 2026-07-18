require "test_helper"

class CreateSongProgressRebuilderTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "test-rebuilder@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    fixture_path = Rails.root.join(
      "test/fixtures/create_song_progress/arabic_disney/https___www_youtube_com_watch_v_1XQaRG4P_9E.json"
    )
    @fixture_data = JSON.parse(File.read(fixture_path))
    @clip_language = Language.find_by!(english_name: @fixture_data["clip_language"])
    @english = languages(:english)

    @progress = CreateSongProgress.create!(
      youtubeurl: @fixture_data["youtubeurl"],
      clip_language: @fixture_data["clip_language"],
      translation_language: @fixture_data["translation_language"],
      data: @fixture_data["data"]
    )

    @course = Course.create!(
      user: @user,
      name: "Test Rebuilder Course",
      slug: "test-rebuilder-course-#{SecureRandom.hex(4)}",
      main_media_url: @fixture_data["youtubeurl"],
      language: @clip_language,
      status: :processing
    )

    CourseBuilder::BuildSong.new(@progress, @course).call
    @course.reload
  end

  test "rebuilds a deleted progress record from the persisted course" do
    @course.update!(create_song_progress: nil)
    @progress.destroy!

    rebuilt = CreateSongProgressRebuilder.new(@course).call

    assert rebuilt.persisted?
    assert_equal @course.main_media_url, rebuilt.youtubeurl
    assert_equal @clip_language.english_name, rebuilt.clip_language
    assert rebuilt.current_data_format?
    assert_equal @course.id, rebuilt.data["rebuilt_from_course_id"]
    assert_equal rebuilt.id, @course.reload.create_song_progress_id

    # Neutral phrases align 1:1 with the persisted rows, in the same order.
    db_phrases = @course.medium.phrases.order(:timestamp).to_a
    assert_equal db_phrases.length, rebuilt.data["phrases"].length
    db_phrases.each_with_index do |phrase, index|
      entry = rebuilt.data["phrases"][index]
      assert_equal phrase.text_l1, entry["text_l1"]
      assert_equal phrase.timestamp, entry["timestamp"]

      tokens = phrase.phrase_tokens.order(:l1_start_index, :id).to_a
      assert_equal tokens.length, entry["words"].length
      tokens.each_with_index do |token, word_index|
        assert_equal token.original_text, entry["words"][word_index]["text"]
      end
    end

    # The already-applied language is backfilled, so it won't be regenerated.
    assert rebuilt.translation_complete?(@english)
    payload = rebuilt.translation_payload(@english)
    db_phrases.each_with_index do |phrase, index|
      assert_equal phrase.phrase_translations.find_by(language: @english)&.text,
                   payload["phrases"][index]["text"]
      tokens = phrase.phrase_tokens.order(:l1_start_index, :id).to_a
      tokens.each_with_index do |token, word_index|
        assert_equal token.token_translations.find_by(language: @english)&.translation,
                     payload["phrases"][index]["words"][word_index]
      end
    end

    # Lesson blocks align 1:1 with the persisted lessons (review lessons included).
    lesson_names = rebuilt.data["lessons"].split("\n\n").map { |block| block.lines.first.strip.sub(/^#\s*/, "") }
    assert_equal @course.lessons.order(:order).pluck(:name), lesson_names
    payload_lesson_names = payload["lessons"].split("\n\n").map { |block| block.lines.first.strip.sub(/^#\s*/, "") }
    assert_equal @course.lessons.order(:order).count, payload_lesson_names.length
  end

  test "fills an existing empty-data record instead of creating a new one" do
    @progress.update!(data: {})

    rebuilt = CreateSongProgressRebuilder.new(@course, progress: @progress).call

    assert_equal @progress.id, rebuilt.id
    assert rebuilt.data["phrases"].present?
    assert rebuilt.translation_complete?(@english)
  end

  test "leaves an intact record untouched" do
    original_data = @progress.data.deep_dup

    result = CreateSongProgressRebuilder.new(@course, progress: @progress).call

    assert_equal @progress.id, result.id
    assert_equal original_data, result.reload.data
  end

  test "raises when the course has no phrases to rebuild from" do
    empty_course = Course.create!(
      user: @user,
      name: "Empty Course",
      slug: "empty-course-#{SecureRandom.hex(4)}",
      main_media_url: "https://www.youtube.com/watch?v=nocontent",
      language: @clip_language,
      status: :pending
    )
    empty_course.course_translations.create!(language: @english, name: "Empty Course", status: :pending)

    assert_raises(ArgumentError) { CreateSongProgressRebuilder.new(empty_course).call }
  end
end
