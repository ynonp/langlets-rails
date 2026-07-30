require "test_helper"

class CourseMailerTest < ActionMailer::TestCase
  setup do
    @user = User.create!(
      email: "course-mailer@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @course = Course.create!(
      user: @user,
      name: "Vicentico - Los Caminos de la Vida (Official Video)",
      slug: "vicentico-los-caminos",
      main_media_url: "https://www.youtube.com/watch?v=example"
    )
  end

  test "creation complete uses Langlet terminology in both formats" do
    email = CourseMailer.creation_complete(@course)

    assert_equal(
      "Your langlet 'Vicentico - Los Caminos de la Vida (Official Video)' is ready!",
      email.subject
    )
    assert_includes email.html_part.body.decoded, "🎉 Your Langlet is Ready!"
    assert_includes email.html_part.body.decoded, "Your langlet"
    assert_includes email.text_part.body.decoded, "Your Langlet is Ready!"
    assert_includes email.text_part.body.decoded, "Your langlet"
  end

  test "creation failed uses Langlet terminology in both formats" do
    email = CourseMailer.creation_failed(@course, StandardError.new("Pipeline stopped"))

    assert_equal(
      "Langlet creation failed for 'Vicentico - Los Caminos de la Vida (Official Video)'",
      email.subject
    )
    assert_includes email.html_part.body.decoded, "Langlet Creation Failed"
    assert_includes email.html_part.body.decoded, "your langlet"
    assert_includes email.text_part.body.decoded, "Langlet Creation Failed"
    assert_includes email.text_part.body.decoded, "your langlet"
  end
end
