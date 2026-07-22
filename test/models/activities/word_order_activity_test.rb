require "test_helper"

class Activities::WordOrderActivityTest < ActiveSupport::TestCase
  setup do
    @language = languages(:english)
    Current.translation_language = @language
    @user = User.create!(
      email: "word-order-queries@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    medium = Medium.create!(url: "https://www.youtube.com/watch?v=wordorder", language: @language)
    course = Course.create!(
      name: "Word order course",
      slug: "word-order-query-course",
      main_media_url: medium.url,
      language: @language,
      user: @user
    )
    lesson = Lesson.create!(
      course: course,
      medium: medium,
      user: @user,
      name: "Word order lesson",
      slug: "word-order-lesson",
      order: 1,
      end_timestamp: "00:10"
    )
    @activity = Activities::WordOrderActivity.create!(lesson: lesson, user: @user, order: 1)
    @activity.define_singleton_method(:video_params) { {} }

    3.times do |index|
      phrase = create_translated_phrase!(
        medium: medium,
        l1: @language,
        text_l1: "word #{index}",
        l2: @language,
        text_l2: "translation #{index}",
        timestamp: "00:0#{index}"
      )
      token = create_translated_token!(
        phrase: phrase,
        language: @language,
        translation: "word",
        l1_start_index: 0,
        l1_end_index: 0,
        index_type: :word_index
      )
      @activity.activity_phrases.create!(phrase: phrase)
      @activity.activity_phrase_tokens.create!(phrase_token: token)
    end
  end

  teardown do
    Current.reset
  end

  test "activity params reuse preloaded tokens and audio attachments for every phrase" do
    queries = capture_selects { @activity.activity_params }

    per_phrase_token_queries = queries.grep(/FROM "phrase_tokens" WHERE "phrase_tokens"\."phrase_id" = /)
    attachment_queries = queries.grep(/FROM "active_storage_attachments"/)

    assert_empty per_phrase_token_queries
    assert_operator attachment_queries.size, :<=, 1
  end

  private

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
