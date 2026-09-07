class DeliverProspectEmailsJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(prospect_id)
    prospect = Prospect.find_by(id: prospect_id)
    return unless prospect

    # Serialize repeated submissions. Track each delivery independently so a
    # failed admin email does not resend a successfully delivered invitation.
    prospect.with_lock do
      unless prospect.invitation_sent_at && prospect.invitation_sent_at > 1.day.ago
        ProspectMailer.with(prospect: prospect).invitation.deliver_now
        prospect.update!(invitation_sent_at: Time.zone.now)
      end
    end

    prospect.with_lock do
      unless prospect.admin_notified_at?
        ProspectMailer.with(prospect: prospect).signup.deliver_now
        prospect.update!(admin_notified_at: Time.zone.now)
      end
    end
  end
end
