require "test_helper"

class UserImportFilteringTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "import-filtering@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
  end

  test "available filters reflect the user's import request states" do
    assert_empty @user.available_import_filters

    create_request("pending", :queued)
    assert_equal %w[pending my_imports], @user.available_import_filters

    create_request("failed", :failed)
    assert_equal %w[pending failed my_imports], @user.available_import_filters
  end

  test "filter scopes share the status definitions used by both libraries" do
    queued = create_request("queued", :queued)
    importing = create_request("importing", :importing)
    failed = create_request("failed", :failed)
    ready = create_request("ready", :ready)
    create_request("canceled", :canceled)

    assert_equal [ queued.id, importing.id ].sort,
                 @user.import_requests_for_filter("pending").pluck(:id).sort
    assert_equal [ failed.id ], @user.import_requests_for_filter("failed").pluck(:id)
    assert_equal [ queued.id, importing.id, failed.id ].sort,
                 @user.import_requests_for_filter("my_imports").pluck(:id).sort
    assert_empty @user.import_requests_for_filter("unknown")
    assert_not_includes @user.import_requests_for_filter("my_imports"), ready
  end

  test "ready imported course ids exclude ready requests without courses" do
    course = Course.create!(
      name: "Ready import", slug: "ready-import-filtering", user: @user,
      language: languages(:spanish), status: :published,
      main_media_url: "https://www.youtube.com/watch?v=kJQP7kiw5Fk"
    )
    create_request("with-course", :ready, course: course)
    create_request("without-course", :ready)

    assert_equal [ course.id ], @user.ready_imported_course_ids.pluck(:course_id)
  end

  private

  def create_request(suffix, status, course: nil)
    @user.import_requests.create!(
      youtube_url: "https://www.youtube.com/watch?v=#{suffix}",
      youtube_video_id: suffix,
      clip_language: "Spanish",
      translation_language: "English",
      status: status,
      course: course
    )
  end
end
