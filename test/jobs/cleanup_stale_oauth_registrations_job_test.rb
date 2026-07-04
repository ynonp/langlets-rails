require "test_helper"

class CleanupStaleOauthRegistrationsJobTest < ActiveJob::TestCase
  test "deletes stale dynamic registrations that never obtained a grant or token" do
    stale = create_application(dynamically_registered: true, created_at: 3.days.ago)

    CleanupStaleOauthRegistrationsJob.perform_now

    assert_not Doorkeeper::Application.exists?(stale.id)
  end

  test "keeps recent dynamic registrations" do
    recent = create_application(dynamically_registered: true, created_at: 1.hour.ago)

    CleanupStaleOauthRegistrationsJob.perform_now

    assert Doorkeeper::Application.exists?(recent.id)
  end

  test "keeps stale dynamic registrations that obtained a token" do
    app = create_application(dynamically_registered: true, created_at: 3.days.ago)
    Doorkeeper::AccessToken.create!(application: app, expires_in: 2.hours)

    CleanupStaleOauthRegistrationsJob.perform_now

    assert Doorkeeper::Application.exists?(app.id)
  end

  test "keeps stale dynamic registrations that obtained a grant" do
    app = create_application(dynamically_registered: true, created_at: 3.days.ago)
    Doorkeeper::AccessGrant.create!(
      application: app,
      resource_owner_id: 1,
      expires_in: 600,
      redirect_uri: app.redirect_uri
    )

    CleanupStaleOauthRegistrationsJob.perform_now

    assert Doorkeeper::Application.exists?(app.id)
  end

  test "never touches manually created applications" do
    manual = create_application(dynamically_registered: false, created_at: 3.days.ago)

    CleanupStaleOauthRegistrationsJob.perform_now

    assert Doorkeeper::Application.exists?(manual.id)
  end

  private

  def create_application(dynamically_registered:, created_at:)
    Doorkeeper::Application.create!(
      name: "Test client #{SecureRandom.hex(4)}",
      redirect_uri: "https://agent.example.com/callback",
      dynamically_registered: dynamically_registered,
      created_at: created_at
    )
  end
end
