require "test_helper"

class CourseShareTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "course-share@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @course = Course.create!(
      user: @user,
      name: "Shareable course",
      slug: "shareable-course-#{SecureRandom.hex(4)}",
      main_media_url: "https://www.youtube.com/watch?v=share123",
      youtube_video_id: "share123",
      status: :published
    )
    publish_covering_the_credit(@user.default_channel, @course)

    post user_session_url,
      params: { user: { email: @user.email, password: "password123" } }
  end

  test "sharing publishes the course to the user's share channel and returns its public URL" do
    balance_before = @user.reload.credit_balance

    post share_course_url(@course.slug), as: :json

    assert_response :success
    body = response.parsed_body
    assert body["shared"]
    assert_equal course_url(@course), body["public_url"]
    assert @user.share_channel.channel_items.exists?(course: @course)
    assert_equal balance_before, @user.reload.credit_balance
  end

  test "a shared course is world-readable" do
    post share_course_url(@course.slug), as: :json
    assert_response :success

    delete destroy_user_session_url
    get course_url(@course.slug)

    assert_response :success
  end

  test "sharing the same course twice does not create a duplicate channel item" do
    2.times { post share_course_url(@course.slug), as: :json }

    assert_equal 1, @user.share_channel.channel_items.where(course: @course).count
  end

  test "unsharing removes it from the share channel and leaves the course intact" do
    post share_course_url(@course.slug), as: :json
    assert_response :success

    post unshare_course_url(@course.slug), as: :json

    assert_response :success
    body = response.parsed_body
    assert_not body["shared"]
    assert_not @user.share_channel.channel_items.exists?(course: @course)
    assert @course.reload.published?
    assert @user.default_channel.channel_items.exists?(course: @course), "the owner's own library is untouched"
  end
end
