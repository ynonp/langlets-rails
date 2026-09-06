require "test_helper"

class AdminPanelTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @admin = User.find_by(email: User::ADMIN_EMAIL) || User.create!(email: User::ADMIN_EMAIL, password: "password123", confirmed_at: Time.zone.now)
    @user = User.create!(email: "panel@example.com", password: "password123", confirmed_at: Time.zone.now)
    @progress = CreateSongProgress.create!(youtubeurl: "https://www.youtube.com/watch?v=adminVid001", clip_language: "Spanish", data: { "errors" => [ { "step" => "translate", "message" => "quota exhausted <script>alert(1)</script>" } ] })
    @course = Course.create!(user: @user, language: languages(:spanish), name: "Admin test course", main_media_url: @progress.youtubeurl, slug: "admin-test-course", status: :error, create_song_progress: @progress)
    @run = ImportRequest.create!(user: @user, course: @course, create_song_progress: @progress, youtube_url: @progress.youtubeurl, youtube_video_id: "adminVid001", clip_language: "Spanish", translation_language: "English", status: :failed, failure_reason: "Quota exhausted")
  end

  test "guests and non-admins cannot read or mutate any admin endpoint" do
    reads = [ admin_root_path, admin_users_path, admin_channels_path, admin_channel_path(@user.default_channel.id), admin_pipeline_runs_path, admin_pipeline_run_path(@run), admin_pipeline_records_path, admin_pipeline_record_path(@progress) ]
    writes = [ grant_pro_admin_user_path(@user), retry_admin_pipeline_run_path(@run) ]
    reads.each { |path| get path; assert_response :redirect }
    writes.each { |path| post path; assert_response :redirect }
    sign_in @user
    assert_no_difference "Subscription.count" do
      assert_no_enqueued_jobs do
        reads.each { |path| get path; assert_response :forbidden }
        writes.each { |path| post path; assert_response :forbidden }
      end
    end
    assert @run.reload.failed?
  end

  test "admin pages render private content and escaped technical errors" do
    sign_in @admin
    ChannelItem.create!(channel: @user.default_channel, course: @course, published_at: Time.zone.now)
    [ admin_root_path, admin_users_path, admin_channels_path, admin_channel_path(@user.default_channel.id), admin_pipeline_runs_path, admin_pipeline_run_path(@run), admin_pipeline_records_path, admin_pipeline_record_path(@progress) ].each do |path|
      get path
      assert_response :success
      assert_select "nav[aria-label='Admin navigation']"
    end
    assert_includes response.body, "quota exhausted &lt;script&gt;"
    assert_select "script", count: 0
    get admin_channel_path(@user.default_channel.id)
    assert_select "a", text: "Admin test course"
  end

  test "granting pro is idempotent and preserves credit balance" do
    sign_in @admin
    balance = @user.credit_balance
    assert_difference "Subscription.count", 1 do
      2.times { post grant_pro_admin_user_path(@user); assert_response :see_other }
    end
    assert @user.reload.pro?
    assert_equal balance, @user.credit_balance
  end

  test "search and status filters narrow results and pagination stays bounded" do
    sign_in @admin
    get admin_users_path(q: @user.email)
    assert_select "td strong", text: @user.email
    assert_select "td strong", text: @admin.email, count: 0
    get admin_pipeline_runs_path(status: "ready")
    assert_select "td", text: "No pipeline requests found."
    get admin_pipeline_runs_path(status: "failed", q: "Quota")
    assert_select "a[href='#{admin_pipeline_run_path(@run)}']"
    get admin_users_path(page: -3)
    assert_response :success
    assert_select "tbody tr", maximum: 30
    get admin_channels_path(q: @user.email)
    assert_select "a[href='#{admin_channel_path(@user.default_channel.id)}']"
  end

  test "retry resumes once and rejects a repeated submission" do
    sign_in @admin
    assert_enqueued_with(job: CreateCourseJob, args: [ @progress.id, @course.id, languages(:english).id ]) do
      post retry_admin_pipeline_run_path(@run)
    end
    assert_redirected_to admin_pipeline_run_path(@run)
    assert @run.reload.queued?
    assert_nil @run.failure_reason
    assert @course.reload.pending?
    assert_no_enqueued_jobs { post retry_admin_pipeline_run_path(@run) }
    assert_match "only a failed import", flash[:alert]
  end

  test "retry without artifacts gives an actionable error" do
    sign_in @admin
    @run.update!(course: nil, create_song_progress: nil)
    assert_no_enqueued_jobs { post retry_admin_pipeline_run_path(@run) }
    assert_match "no course to resume", flash[:alert]
    assert @run.reload.failed?
  end
end
