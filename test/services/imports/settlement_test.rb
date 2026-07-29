require "test_helper"

class Imports::SettlementTest < ActiveJob::TestCase
  test "completion enrolls and publishes to the importing user's default channel idempotently" do
    user = User.create!(email: "settlement-channel@example.com", password: "password123", confirmed_at: Time.zone.now)
    course = Course.create!(
      user: user, language: languages(:spanish), name: "Settled", slug: "settled-channel-course",
      main_media_url: "https://youtu.be/settledchan", youtube_video_id: "settledchan", status: :published
    )
    request = user.import_requests.create!(
      youtube_url: course.main_media_url, youtube_video_id: course.youtube_video_id,
      clip_language: "Spanish", translation_language: "English", course: course,
      status: :importing, charged: true
    )

    2.times { Imports::Settlement.complete!(request.reload) }

    assert request.reload.ready?
    assert user.enrollments.exists?(course: course)
    assert_equal 1, user.default_channel.channel_items.where(course: course).count
  end
end
