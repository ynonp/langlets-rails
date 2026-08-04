require "test_helper"

class CourseBuilder::BuildSongTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "test-build-song@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    @english = languages(:english)
    # Use a word-timed fixture with actual similar_sounds data.
    fixture_path = Rails.root.join(
      "test/fixtures/create_song_progress/arabic_disney/https___www_youtube_com_watch_v_1XQaRG4P_9E.json"
    )
    @fixture_data = JSON.parse(File.read(fixture_path))
    @clip_language = Language.find_by!(english_name: @fixture_data["clip_language"])

    @progress = CreateSongProgress.new(
      youtubeurl: @fixture_data["youtubeurl"],
      clip_language: @fixture_data["clip_language"],
      data: @fixture_data["data"]
    )
    @progress.save!

    @course = Course.create!(
      user: @user,
      name: "Test Bref Course",
      slug: "test-bref-course-#{SecureRandom.hex(4)}",
      main_media_url: @fixture_data["youtubeurl"],
      language: @clip_language,
      status: :processing
    )
  end

  test "phrases have similar sounds after build" do
    builder = CourseBuilder::BuildSong.new(@progress, @course)
    builder.call(@english)

    @course.reload

    phrases = @course.lessons.first.medium.phrases
    phrases_with_similar = phrases.select { |p| p.similar_sounds.any? }

    refute_empty phrases_with_similar,
      "Expected some phrases to have similar sounds, but none do"

    # At least some phrases should have similar sounds for the ListenActivity to work
    assert phrases_with_similar.count >= 1,
      "Expected at least 1 phrase with similar sounds, got #{phrases_with_similar.count}"
  end

  test "ListenActivity in lesson 2 has phrases with similar sounds" do
    builder = CourseBuilder::BuildSong.new(@progress, @course)
    builder.call(@english)

    @course.reload

    lesson2 = @course.lessons.find_by(order: 2)
    assert lesson2, "Lesson 2 should exist"

    activity5 = lesson2.activities.find_by(order: 6)
    assert activity5, "Activity 5 should exist in lesson 2"
    assert_instance_of Activities::ListenActivity, activity5

    # The ListenActivity's phrases should have token translations AND similar sounds
    phrases_with_tt = activity5.phrases.select { |p| p.phrase_tokens.any? { |t| t.token_translations.any? } }
    refute_empty phrases_with_tt, "Phrases should have token translations"

    phrases_with_similar = phrases_with_tt.select { |p| p.similar_sounds.any? }
    refute_empty phrases_with_similar,
      "Phrases in ListenActivity should have similar sounds for interactive blanks, got 0"
  end

  test "all ListenActivity and SpeakActivity instances have phrases with similar sounds" do
    builder = CourseBuilder::BuildSong.new(@progress, @course)
    builder.call(@english)

    @course.reload

    listen_and_speak = @course.lessons.flat_map(&:activities).select do |a|
      a.is_a?(Activities::ListenActivity) || a.is_a?(Activities::SpeakActivity)
    end

    refute_empty listen_and_speak, "Should have ListenActivity/SpeakActivity instances"

    listen_and_speak.each do |activity|
      phrases_with_similar = activity.phrases.select { |p| p.similar_sounds.any? }
      assert phrases_with_similar.any?,
        "#{activity.type} in lesson #{activity.lesson.order} ('#{activity.lesson.name}') should have phrases with similar sounds"
    end
  end

  test "similar_sounds data is not empty in the fixture" do
    # Verify the fixture itself has valid similar_sounds data
    ss = @fixture_data.dig("data", "similar_sounds")
    assert ss.present?, "Fixture similar_sounds should not be blank"
    assert ss.strip.lines.count > 1, "Fixture similar_sounds should have multiple lines"
  end
end
