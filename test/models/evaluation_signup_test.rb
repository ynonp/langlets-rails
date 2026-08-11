require "test_helper"

class EvaluationSignupTest < ActiveJob::TestCase
  setup do
    @admin = User.create!(email: "evaluation-admin@example.com", password: "password123", confirmed_at: Time.zone.now)
    @learner = User.create!(email: "evaluation-learner@example.com", password: "password123", confirmed_at: Time.zone.now)
    @progress = CreateSongProgress.create!(youtubeurl: "https://www.youtube.com/watch?v=evaluation1", data: {})
    @course = Course.create!(
      user: @admin,
      name: "Evaluation video",
      slug: "evaluation-video",
      main_media_url: @progress.youtubeurl,
      youtube_video_id: "evaluation1",
      create_song_progress: @progress,
      status: :pending
    )
    @source = @admin.import_requests.create!(
      youtube_url: @progress.youtubeurl,
      youtube_video_id: "evaluation1",
      translation_language: "English",
      title: @course.name,
      course: @course,
      create_song_progress: @progress,
      status: :detecting,
      guest_started: true
    )
    @evaluation = EvaluationSignup.create!(
      admin_import_request: @source,
      initial_course: @course,
      course: @course,
      video_url: @progress.youtubeurl,
      video_id: "evaluation1",
      provider: "youtube",
      title: @course.name,
      translation_language: "English"
    )
  end

  test "gets a database-generated UUID" do
    assert_match(/\A[0-9a-f-]{36}\z/, @evaluation.token)
  end

  test "claim links the user and creates one request for the same course" do
    request = @evaluation.claim!(@learner)

    assert_equal @evaluation, @learner.reload.evaluation_signup
    assert_equal @learner, @evaluation.reload.user
    assert @evaluation.claimed_at?
    assert_equal @course, request.course
    assert request.detecting?

    assert_no_difference -> { @learner.import_requests.count } do
      assert_equal request, @evaluation.claim!(@learner)
    end
  end

  test "a different user cannot take a claimed evaluation" do
    @evaluation.claim!(@learner)
    stranger = User.create!(email: "evaluation-stranger@example.com", password: "password123", confirmed_at: Time.zone.now)

    assert_raises(ActiveRecord::RecordNotFound) { @evaluation.claim!(stranger) }
    assert_equal @learner, @evaluation.reload.user
  end

  test "claiming a newer evaluation replaces and consumes the previous one" do
    @evaluation.claim!(@learner)
    newer = EvaluationSignup.create!(
      admin_import_request: @source,
      initial_course: @course,
      course: @course,
      video_url: @progress.youtubeurl,
      video_id: "evaluation2",
      provider: "youtube",
      title: "Newer evaluation video",
      translation_language: "English"
    )

    newer.claim!(@learner)

    assert_equal newer, @learner.reload.evaluation_signup
    assert @evaluation.reload.consumed_at?
    assert_nil @evaluation.user
  end

  test "an expired evaluation cannot be claimed" do
    @evaluation.update_column(:created_at, 2.days.ago)

    assert_raises(ActiveRecord::RecordNotFound) { @evaluation.claim!(@learner) }
    assert_nil @learner.reload.evaluation_signup
  end

  test "consume records the first login once" do
    @evaluation.consume!
    first_consumed_at = @evaluation.consumed_at

    travel 1.minute do
      @evaluation.consume!
    end

    assert_equal first_consumed_at, @evaluation.reload.consumed_at
  end
end
