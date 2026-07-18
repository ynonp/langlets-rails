require "test_helper"

class EnrollmentTest < ActiveSupport::TestCase
  setup do
    @user   = User.create!(email: "enrol@example.com", password: "password123", confirmed_at: Time.zone.now)
    @course = Course.create!(name: "Enrolment Course", slug: "enrolment-course",
                             main_media_url: "https://www.youtube.com/watch?v=enrol123", user: @user)
  end

  test "a user can only be enrolled in a course once" do
    Enrollment.create!(user: @user, course: @course, source: :library)

    duplicate = Enrollment.new(user: @user, course: @course, source: :imported)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:course_id], "has already been taken"
  end

  test "recently_practiced sorts unopened enrollments last" do
    other = Course.create!(name: "Other Course", slug: "other-course",
                           main_media_url: "https://www.youtube.com/watch?v=other123", user: @user)
    never_opened = Enrollment.create!(user: @user, course: other, source: :library)
    practised    = Enrollment.create!(user: @user, course: @course, source: :library,
                                      last_practiced_at: 1.hour.ago)

    assert_equal [ practised.id, never_opened.id ],
                 @user.enrollments.recently_practiced.pluck(:id)
  end

  class LessonProgressTest < ActiveSupport::TestCase
    setup do
      @user     = User.create!(email: "progress@example.com", password: "password123", confirmed_at: Time.zone.now)
      @spanish  = languages(:spanish)
      @english  = languages(:english)
      @medium   = Medium.create!(url: "https://www.youtube.com/watch?v=progress99",
                                 language: @spanish)
      @course   = Course.create!(name: "Progress Course", slug: "progress-course",
                                 main_media_url: @medium.url, user: @user)
      @lesson   = Lesson.create!(course: @course, medium: @medium, user: @user,
                                 slug: "lesson-1", name: "Lesson 1", order: 0)
    end

    # Someone can reach a lesson without ever touching Home — a shared link, a
    # learning path. Completing it has to put the course on their Home, or the
    # thing they're part-way through is invisible there.
    test "completing a lesson enrolls a user who was not enrolled" do
      assert_equal 0, @user.enrollments.where(course: @course).count

      LessonUser.create!(lesson: @lesson, user: @user)

      enrollment = @user.enrollments.sole
      assert_equal @course, enrollment.course
      assert enrollment.library?
      assert_not_nil enrollment.last_practiced_at
    end

    test "completing a lesson moves last_practiced_at without changing the source" do
      enrollment = Enrollment.create!(user: @user, course: @course, source: :imported,
                                      last_practiced_at: 2.days.ago)
      was = enrollment.last_practiced_at

      LessonUser.create!(lesson: @lesson, user: @user)

      enrollment.reload
      assert_operator enrollment.last_practiced_at, :>, was
      assert enrollment.imported?, "source must survive — they still imported it"
    end
  end
end
