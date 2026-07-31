require "test_helper"

class BuildReviewLessonJobTest < ActiveJob::TestCase
  setup do
    @user = User.create!(
      email: "review-job@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @english = languages(:english)
  end

  test "creates the lesson and marks the durable request ready" do
    build = @user.review_lesson_builds.create!(language: @english)

    assert_difference([ "Lesson.count", "Activity.count" ], 1) do
      BuildReviewLessonJob.perform_now(build.id)
    end

    build.reload
    assert build.ready?
    assert_equal @user, build.lesson.user
    assert_equal @english, build.lesson.review_language
  end

  test "a repeated execution does not create a second lesson" do
    build = @user.review_lesson_builds.create!(language: @english)
    BuildReviewLessonJob.perform_now(build.id)

    assert_no_difference([ "Lesson.count", "Activity.count" ]) do
      BuildReviewLessonJob.perform_now(build.id)
    end
  end

  test "a cable outage does not turn a completed build into a failure" do
    build = @user.review_lesson_builds.create!(language: @english)
    unavailable = ->(*, **) { raise "cable unavailable" }

    Turbo::StreamsChannel.stub(:broadcast_action_to, unavailable) do
      BuildReviewLessonJob.perform_now(build.id)
    end

    assert build.reload.ready?
    assert build.lesson.present?
  end

  test "records failure without leaving a partial lesson" do
    build = @user.review_lesson_builds.create!(language: @english)
    failing_builder = ->(*) { raise "vocabulary exploded" }

    assert_no_difference("Lesson.count") do
      assert_raises(RuntimeError) do
        ReviewLessonBuilder.stub(:new, failing_builder) do
          BuildReviewLessonJob.perform_now(build.id)
        end
      end
    end

    assert build.reload.failed?
    assert_equal "vocabulary exploded", build.error
    assert_nil build.lesson
  end
end
