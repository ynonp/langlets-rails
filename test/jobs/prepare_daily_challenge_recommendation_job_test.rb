require "test_helper"

class PrepareDailyChallengeRecommendationJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    travel_to Time.zone.local(2026, 10, 3, 12)
    @user = User.create!(email: "daily-video@example.test", password: "password123")
    @challenge = StarterChallenge.enroll!(user: @user, language_ids: [ languages(:french).id ], delivery: [ "email" ])
    travel_to @challenge.local_time_on(@challenge.first_challenge_on + 5) - 20.minutes
    @quest = DailyChallenge.ensure_personalized_today!(@challenge)
    @url = "https://www.youtube.com/watch?v=kJQP7kiw5Fk"
    video = VideoSource::Video.new(video_id: "kJQP7kiw5Fk", title: "French conversation", author_name: "French teacher",
      canonical_url: @url, thumbnail_url: "https://img.youtube.com/vi/kJQP7kiw5Fk/hqdefault.jpg")
    @preflight = Imports::VideoPreflight::Result.new(video: video, duration_seconds: 180, maximum_duration_seconds: 1500)
  end

  test "prepares a source card without importing or notifying early and sends one challenge at the chosen time" do
    assert_no_difference [ "ImportRequest.count", "Course.count", "Notification.count" ] do
      prepare
    end
    assert_equal "ready", @quest.reload.recommendation_state
    assert_equal @url, @quest.recommended_video["url"]
    assert_equal "French teacher", @quest.recommended_video["channel"]
    assert_equal "dialogue", @quest.recommended_video["content_type"]
    assert_equal [ @quest.recommended_video ], @quest.videos_for("fr")
    assert_empty @quest.videos_for("es")
    travel_to @quest.available_at
    assert_difference "Notification.count", 1 do
      2.times { SendDailyChallengesJob.perform_now }
    end
    notification = @quest.reload.notification
    assert_equal "daily_challenge", notification.kind
    assert_equal "/daily_challenge", notification.url
    assert_nil notification.data["course_slug"]
    %w[en he es].each do |locale|
      assert_includes notification.body(locale: locale), "French conversation"
      assert_no_match(/translation_missing|Translation missing/, notification.title(locale: locale))
    end
    assert_equal 0, @challenge.daily_practice_reminders.count
  end

  test "late recommendations notify when ready and only for their current local date" do
    travel_to @quest.available_at + 1.hour
    assert_difference "Notification.count", 1 do
      2.times { prepare }
    end
    notification = @quest.reload.notification
    travel_to @quest.available_at + 1.day
    assert_emails(0) { DeliverNotificationJob.perform_now(notification.id) }
    assert notification.reload.sent_at?
  end

  test "search failures stop after three attempts with no generic notification" do
    DailyVideoRecommendation.stub(:call, ->(**) { raise DailyVideoRecommendation::InvalidRecommendation }) do
      assert_no_difference "Notification.count" do
        4.times { PrepareDailyChallengeRecommendationJob.perform_now(@quest.id) }
      end
    end
    assert_equal "failed", @quest.reload.recommendation_state
    assert_equal 3, @quest.search_attempts
  end

  test "abandoned search resumes but live lease prevents duplicate searches" do
    @quest.update!(recommendation_state: "searching", search_started_at: Time.zone.now)
    DailyVideoRecommendation.stub(:call, ->(**) { flunk "search in flight" }) do
      PrepareDailyChallengeRecommendationJob.perform_now(@quest.id)
    end
    @quest.update!(search_started_at: Time.zone.now - 11.minutes)
    prepare
    assert_equal "ready", @quest.reload.recommendation_state
  end

  test "outdated quests never search or notify" do
    travel_to @quest.available_at + 1.day
    DailyVideoRecommendation.stub(:call, ->(**) { flunk "outdated quest" }) do
      assert_no_difference("Notification.count") { PrepareDailyChallengeRecommendationJob.perform_now(@quest.id) }
    end
    assert @quest.reload.skipped_at?
  end

  test "unavailable videos do not populate the import list" do
    DailyVideoRecommendation.stub(:call, DailyVideoRecommendation::Result.new(url: @url, search_suggestions: nil)) do
      Imports::VideoPreflight.stub(:call, ->(*) { raise VideoSource::UnavailableVideo }) do
        PrepareDailyChallengeRecommendationJob.perform_now(@quest.id)
      end
    end
    assert_empty @quest.reload.recommended_video
    assert_nil @quest.notification
  end

  private

  def prepare
    DailyVideoRecommendation.stub(:call, ->(**args) { assert_equal @user, args[:user]; assert_equal languages(:french), args[:language]; DailyVideoRecommendation::Result.new(url: @url, search_suggestions: nil, content_type: "dialogue") }) do
      Imports::VideoPreflight.stub(:call, @preflight) { PrepareDailyChallengeRecommendationJob.perform_now(@quest.id) }
    end
  end
end
