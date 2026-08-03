module Imports
  # How an import ends, either way. Four callers need exactly this and used to
  # each carry their own copy: Imports::Finalizer (the data arrived),
  # ImportRequestTimeoutJob (it never did), the trigger jobs (the run never
  # started), and Imports::Create when there was nothing to run at all. Keeping
  # it in one place is what stops them drifting apart.
  module Settlement
    module_function

    # The course exists now, so this is the point where it becomes the user's:
    # published into their channel, paid for there, and on their Home.
    #
    # `notify:` is false for the one import that never waited — Imports::Create
    # adopting an already-built course — because a "your course is ready" push
    # for something the user is looking at right now is noise.
    #
    # Raises Credits::InsufficientCredits if the balance ran out between the
    # request and its delivery, which rolls the whole settlement back and leaves
    # the import to fail with that as its reason. Imports::Pricing guards against
    # it at request time; this is the residual race, and failing here is right —
    # the alternative is handing over a course nobody paid for.
    def complete!(import_request, notify: true)
      # The pipeline's branches run concurrently, so two callbacks can both find
      # this request complete and both reach here at once (see
      # PipelineCallbacksController#finalize_later). publish! and enroll! are
      # already safe to repeat (course-level lock, RecordNotUnique rescue), so
      # they stay unguarded; what isn't safe to repeat is telling the user twice.
      # The row lock serializes the racing `update!` calls, so only the one that
      # actually flips the status notifies — the other finds it already `ready`
      # and its own update is a no-op.
      #
      # Imports::Create#adopt! writes `ready` itself before calling this, so its
      # update here is a no-op too — harmless, because it always calls with
      # notify: false.
      newly_settled = ImportRequest.transaction do
        import_request.lock!

        # Pro imports land in the Pro library rather than the user's own default
        # Channel — see User#publishing_channel. Which one it is has to be
        # decided here, at publication, because it is a fact about this import
        # rather than about the account today. It is also what decides the price:
        # Channel#publish! charges, and ProChannel#publish! does not.
        import_request.user.publishing_channel.publish!(import_request.course)
        enroll!(import_request)
        import_request.update!(status: :ready, progress_percent: 100, failure_reason: nil)
        import_request.saved_change_to_status?
      end

      return unless newly_settled
      return unless notify

      # One call for both channels: Notifications records it, then delivers it
      # by email and/or push according to the user's preference, in a job — so a
      # delivery failure can't fail an import that has already succeeded.
      Notifications.deliver(
        user: import_request.user,
        kind: :course_ready,
        course: import_request.course,
        title: import_request.title
      )
    end

    # Record why, and stop. There is deliberately no refund here any more: a
    # credit only moves when a course is published into the user's channel
    # (Channel#publish!), and a failed import never got that far. Nothing was
    # taken, so there is nothing to give back — which also means there is no
    # refund idempotency to get wrong, and no way for a re-run to mint credits.
    def fail!(import_request, reason)
      # Already failed: a second caller reaching the same conclusion (the
      # finalizer and the timeout job can race) must not tell the user twice.
      already_failed = import_request.failed?

      import_request.status = :failed
      import_request.failure_reason = reason.to_s.truncate(250)
      import_request.save!

      return if already_failed

      # Every way an import can die comes through here — the finalizer, the
      # timeout job, both trigger jobs — which is why the "we couldn't build it"
      # notification is here and not in each of them. It goes to the user who
      # asked, not to the course's creator: on a joined import those are
      # different people, and only one of them is waiting.
      Notifications.deliver(
        user: import_request.user,
        kind: :course_failed,
        course: import_request.course,
        title: import_request.title,
        reason: reason
      )
    rescue => e
      # Never let bookkeeping bury the original failure.
      Rails.logger.error "Failed to settle ImportRequest #{import_request.id}: #{e.message}"
    end

    def fail_all!(import_requests, reason)
      import_requests.each { |import_request| fail!(import_request, reason) }
    end

    def enroll!(import_request)
      # Always `imported`. An ImportRequest *is* somebody asking for a course of
      # their own, and every one of them now ends with that course published into
      # their channel and paid for — by a credit, or by the subscription that
      # makes it free. There is no longer a free rider to tell apart, which is
      # what this used to read `charged`/`pro_covered` to work out.
      # `library` remains what the catalog's "+ Learn this" writes.
      enrollment = Enrollment.find_or_initialize_by(user_id: import_request.user_id, course_id: import_request.course_id)
      enrollment.source = :imported if enrollment.new_record?
      enrollment.save!
    rescue ActiveRecord::RecordNotUnique
      nil # already enrolled, nothing to do
    end
  end
end
