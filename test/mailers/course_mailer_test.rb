require "test_helper"

class CourseMailerTest < ActionMailer::TestCase
  test "creation_complete" do
    mail = CourseMailer.creation_complete
    assert_equal "Creation complete", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end

  test "creation_failed" do
    mail = CourseMailer.creation_failed
    assert_equal "Creation failed", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
