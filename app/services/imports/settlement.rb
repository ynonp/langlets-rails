module Imports
  # How an import ends, either way. Three callers need exactly this and used to
  # each carry their own copy: Imports::Finalizer (the data arrived),
  # ImportRequestTimeoutJob (it never did), and the trigger jobs (the run never
  # started). Keeping it in one place is what stops the refund rules from
  # drifting apart between them.
  module Settlement
    module_function

    # The course exists now, so this is the point where it may appear on Home.
    def complete!(import_request)
      enroll!(import_request)
      import_request.update!(status: :ready, progress_percent: 100, failure_reason: nil)

      # Separate job so a push failure can't fail an import that has already
      # succeeded. The completion email goes out from the finalizer regardless —
      # it's the fallback for anyone who never granted notification permission.
      SendImportReadyPushJob.perform_later(import_request.id)
    end

    # Give the credit back. Only whoever actually paid gets a refund — users who
    # joined someone else's in-flight import were never charged. The idempotency
    # key means a manual re-run can't refund twice.
    def fail!(import_request, reason)
      if import_request.charged? && !import_request.refunded?
        Credits::Ledger.refund!(
          user: import_request.user,
          subject: import_request,
          idempotency_key: "refund:#{import_request.id}"
        )
        import_request.refunded = true
      end

      import_request.status = :failed
      import_request.failure_reason = reason.to_s.truncate(250)
      import_request.save!
    rescue => e
      # Never let bookkeeping bury the original failure.
      Rails.logger.error "Failed to settle ImportRequest #{import_request.id}: #{e.message}"
    end

    def fail_all!(import_requests, reason)
      import_requests.each { |import_request| fail!(import_request, reason) }
    end

    def enroll!(import_request)
      source = import_request.charged? ? :imported : :library
      enrollment = Enrollment.find_or_initialize_by(user_id: import_request.user_id, course_id: import_request.course_id)
      enrollment.source = source if enrollment.new_record?
      enrollment.save!
    rescue ActiveRecord::RecordNotUnique
      nil # already enrolled, nothing to do
    end
  end
end
