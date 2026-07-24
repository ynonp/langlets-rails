require "test_helper"

class Activities::LanguageAlignmentActivityTest < ActiveSupport::TestCase
  setup do
    @language = languages(:english)
    Current.translation_language = @language
    user = User.create!(
      email: "language-alignment-queries@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    medium = Medium.create!(url: "https://www.youtube.com/watch?v=alignment", language: @language)
    course = Course.create!(
      name: "Alignment course",
      slug: "alignment-query-course",
      main_media_url: medium.url,
      language: @language,
      user: user
    )
    lesson = Lesson.create!(
      course: course,
      medium: medium,
      user: user,
      name: "Alignment lesson",
      slug: "alignment-lesson",
      order: 1
    )
    @activity = Activities::LanguageAlignmentActivity.create!(lesson: lesson, user: user, order: 1)

    selected_phrase = create_phrase_with_token!(medium, "selected phrase", "00:10")
    @activity.activity_phrases.create!(phrase: selected_phrase)
    @activity.activity_phrase_tokens.create!(phrase_token: selected_phrase.phrase_tokens.first)

    20.times do |index|
      phrase = create_phrase_with_token!(medium, "unused phrase #{index}", format("00:%02d", index + 20))
      @activity.activity_phrases.create!(phrase: phrase)
    end
  end

  teardown do
    Current.reset
  end

  test "hydrates only phrases that own selected activity tokens" do
    queries = capture_selects do
      params = @activity.activity_params

      assert_equal [ "selected phrase" ], params[:phrases_with_tokens].map { |row| row[:phrase].text_l1 }
      assert_equal 1, params[:phrases_with_tokens].first[:tokens].size
      assert_equal "00:10", params[:start_timestamp]
      assert_equal "00:44.00", params[:end_timestamp]
    end

    refute queries.any? { |sql| sql.match?(/FROM "phrase_tokens".*WHERE "phrase_tokens"\."phrase_id" IN/) }
    assert queries.any? { |sql| sql.include?('INNER JOIN "activity_phrase_tokens"') }
  end

  private

  def create_phrase_with_token!(medium, text, timestamp)
    phrase = create_translated_phrase!(
      medium: medium,
      l1: @language,
      text_l1: text,
      l2: @language,
      text_l2: "translated #{text}",
      timestamp: timestamp
    )
    create_translated_token!(
      phrase: phrase,
      language: @language,
      translation: text.split.first,
      l1_start_index: 0,
      l1_end_index: text.split.first.length - 1,
      l2_start_index: 0,
      l2_end_index: 9,
      index_type: :character_index
    )
    phrase
  end

  def capture_selects
    queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == "SCHEMA" || payload[:cached]

      queries << payload[:sql].squish if payload[:sql].to_s.lstrip.start_with?("SELECT")
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end
end
