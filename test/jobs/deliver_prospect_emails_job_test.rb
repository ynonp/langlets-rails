require "test_helper"

class DeliverProspectEmailsJobTest < ActiveJob::TestCase
  setup { @prospect = Prospect.create!(email: "mail-retry@example.com") }

  test "successful invitation stays recorded if admin delivery fails" do
    invitation = Minitest::Mock.new
    invitation.expect :deliver_now, true
    admin_mail = Object.new
    def admin_mail.deliver_now = raise IOError, "temporary mail failure"
    mailer = Object.new
    mailer.define_singleton_method(:invitation) { invitation }
    mailer.define_singleton_method(:signup) { admin_mail }
    ProspectMailer.stub :with, mailer do
      assert_raises(IOError) { DeliverProspectEmailsJob.new.perform(@prospect.id) }
    end
    assert @prospect.reload.invitation_sent_at
    assert_nil @prospect.admin_notified_at
    invitation.verify

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      DeliverProspectEmailsJob.new.perform(@prospect.id)
    end
    assert_equal [ User::ADMIN_EMAIL ], ActionMailer::Base.deliveries.last.to
  end

  test "expired invitation can be renewed without notifying admin twice" do
    DeliverProspectEmailsJob.new.perform(@prospect.id)
    travel 8.days do
      assert_difference "ActionMailer::Base.deliveries.size", 1 do
        DeliverProspectEmailsJob.new.perform(@prospect.id)
      end
      assert_equal [ @prospect.email ], ActionMailer::Base.deliveries.last.to
      assert_equal Time.zone.now.to_i, @prospect.reload.invitation_sent_at.to_i
    end
  end

  test "activated prospects receive a sign in link on later submissions" do
    @prospect.update!(activated_at: Time.zone.now, admin_notified_at: Time.zone.now)
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      DeliverProspectEmailsJob.new.perform(@prospect.id)
    end
    body = ActionMailer::Base.deliveries.last.text_part.body.decoded
    assert_includes body, "/users/sign_in"
    assert_not_includes body, "setup?token="
  end
end
