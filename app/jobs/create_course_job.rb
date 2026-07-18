class CreateCourseJob < ApplicationJob
  queue_as :default

  # No retry_on, deliberately. good_job's retry_on_unhandled_error defaults to
  # false and this app doesn't override it, so a raise here is final — which is
  # what makes refunding in the rescue below correct rather than a balance
  # yo-yo. It would also be unsafe to add naively: the rescue sets the course to
  # `error`, and Course#process only claims a `pending` course, so a second
  # attempt would silently do nothing.
  def perform(create_song_progress_id, course_id)
    progress = CreateSongProgress.find(create_song_progress_id)
    course = Course.find(course_id)

    course_created = course.process do |course|
      Rails.logger.info "Starting CreateCourseJob #{create_song_progress_id} / #{course_id}"
      # Inside the claim: only the job that actually owns this course should move
      # its requests. If another job holds it, that one has already done this.
      start_imports!(course)
      create_course_from_progress(progress, course)
    end

    Rails.logger.info "Another job already processing or completed CreateSongProgress #{create_song_progress_id} / #{course_id}" unless course_created

  rescue => e
    # course is nil when the find itself failed; without the guard the
    # NoMethodError would mask the real error.
    course&.error!
    fail_imports!(course, e) if course

    Rails.logger.error "Course creation failed for course #{course_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # Send failure email
    CourseMailer.creation_failed(course, e).deliver_now if course
    raise e
  end

  private

  def create_course_from_progress(progress, course)
    progress.create_data
    progress.reload
    course.reload

    builder = CourseBuilder::BuildSong.new(progress, course)
    builder.call

    requested_languages = imports_for(course).distinct.pluck(:translation_language)
    requested_languages.each do |language_name|
      next if language_name == progress.translation_language

      language = Language.find_by(english_name: language_name)
      next if language.nil? || course.reload.translation_ready?(language)

      progress.add_translation(language)
    end

    course.published!
    complete_imports!(course)
    CourseMailer.creation_complete(course).deliver_now
  end

  # Requests waiting on this course. Usually one, but several users can ride on a
  # single import (see Imports::Create#join!).
  def imports_for(course)
    ImportRequest.where(course_id: course.id).where(status: [ :queued, :importing ])
  end

  def start_imports!(course)
    imports_for(course).update_all(status: ImportRequest.statuses[:importing], updated_at: Time.zone.now)
  end

  # The course exists now, so this is the point where it may appear on Home.
  def complete_imports!(course)
    imports_for(course).find_each do |import_request|
      enroll!(import_request)
      import_request.update!(status: :ready, progress_percent: 100, failure_reason: nil)

      # Separate job so a push failure can't fail an import that has already
      # succeeded. The completion email still goes out below regardless — it's
      # the fallback for anyone who never granted notification permission.
      SendImportReadyPushJob.perform_later(import_request.id)
    end
  end

  def enroll!(import_request)
    source = import_request.charged? ? :imported : :library
    enrollment = Enrollment.find_or_initialize_by(user_id: import_request.user_id, course_id: import_request.course_id)
    enrollment.source = source if enrollment.new_record?
    enrollment.save!
  rescue ActiveRecord::RecordNotUnique
    nil # already enrolled, nothing to do
  end

  # Give the credit back. Only whoever actually paid gets a refund — users who
  # joined someone else's in-flight import were never charged. The idempotency
  # key means a manual re-run can't refund twice.
  def fail_imports!(course, error)
    imports_for(course).find_each do |import_request|
      if import_request.charged? && !import_request.refunded?
        Credits::Ledger.refund!(
          user: import_request.user,
          subject: import_request,
          idempotency_key: "refund:#{import_request.id}"
        )
        import_request.refunded = true
      end

      import_request.status = :failed
      import_request.failure_reason = error.message.to_s.truncate(250)
      import_request.save!
    end
  rescue => e
    # Never let bookkeeping bury the original failure.
    Rails.logger.error "Failed to fail imports for course #{course.id}: #{e.message}"
  end
end
