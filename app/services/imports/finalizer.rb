module Imports
  # Asks the one question the pipeline can't answer for us: is this record
  # holding everything the people waiting on it asked for?
  #
  # The pipeline streams patches to PipelineCallbacksController and then simply
  # stops — there is no "run finished" event to subscribe to. So completion is a
  # property of CreateSongProgress#data, re-derived after every callback rather
  # than signalled once. That makes this idempotent by construction: every
  # callback asks again, and whichever one first finds a complete blob does the
  # work under the course's row lock while the rest find it already done.
  #
  # It is also the only place a course gets published, which is why the timeout
  # job calls it once more before giving up — the last patch and the finalizer
  # that acts on it are not atomic, and a request must never fail with its data
  # sitting right there.
  class Finalizer
    def self.call(...) = new(...).call

    def initialize(progress)
      @progress = progress
    end

    def call
      @progress.reload

      finalize_requested_course_translations
      pending_requests.each { |import_request| settle(import_request) }
    end

    private

    attr_reader :progress

    # Course-page translation requests deliberately have no ImportRequest: an
    # ImportRequest ends by publishing into a user's Channel and charging for
    # that publication. Pending CourseTranslation rows are their durable work
    # marker instead. Finalize them from the same callback-driven path, adding
    # only localized rows to the already-published course skeleton.
    def finalize_requested_course_translations
      CourseTranslation.pending
        .joins(:course)
        .where(courses: { create_song_progress_id: progress.id })
        .includes(:language, :course)
        .find_each do |translation|
          # Ordinary imports are settled below; only the course-page path lacks
          # an ImportRequest and needs this direct finalization branch.
          next if ImportRequest.active.exists?(
            course_id: translation.course_id,
            translation_language: translation.language.english_name
          )

          if progress.blocking_error(since: translation.updated_at)
            translation.error!
            next
          end
          next unless progress.complete_for?(translation.language)

          translation.course.with_lock do
            translation.course.reload
            unless translation.course.translation_ready?(translation.language)
              CourseBuilder::BuildSong.new(progress, translation.course).add_translation(translation.language)
            end
          end
        end
    end

    # Usually one, but several users can ride on a single import (see
    # Imports::Create#join!), and they can be waiting on different languages.
    def pending_requests
      ImportRequest.active
                   .where(create_song_progress_id: progress.id)
                   .where.not(course_id: nil)
                   .includes(:course, :user)
                   .to_a
    end

    def settle(import_request)
      # Errors that predate this request belong to somebody else's run: a
      # resumed pipeline skips the steps it already finished, so it never gets
      # the chance to clear their entries.
      if (failure = progress.blocking_error(since: import_request.created_at))
        fail!(import_request, failure["error_message"].presence || failure["step"])
        return
      end

      language = language_for(import_request)
      return unless progress.complete_for?(language)

      publish!(import_request.course, language)
      Settlement.complete!(import_request)
    rescue Credits::InsufficientCredits => e
      # The balance ran out between asking for this import and it being ready to
      # hand over. Imports::Pricing guards the front door, but nothing holds a
      # credit in between, so this is the one failure the user can still fix.
      #
      # Caught separately because `failure_reason` is user-facing — the share
      # extension reads it straight out of the API — and Credits::Ledger's own
      # message names an internal user id. Say the one thing they can act on.
      Rails.logger.warn "ImportRequest #{import_request.id} could not be delivered: #{e.message}"
      fail!(import_request, ImportRequest::INSUFFICIENT_CREDITS)
    rescue => e
      Rails.logger.error "Finalizing ImportRequest #{import_request.id} failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      fail!(import_request, e.message)
    end

    # Building is the expensive, destructive part, so it happens once per course
    # under a row lock: two languages completing at the same moment would
    # otherwise both find no lessons and both run BuildSong#call, and the second
    # one destroys the first one's lessons out from under it.
    def publish!(course, language)
      newly_published = false

      course.with_lock do
        course.reload

        CourseBuilder::BuildSong.new(progress, course).call(language) unless course.lessons.exists?
        unless course.translation_ready?(language)
          CourseBuilder::BuildSong.new(progress, course).add_translation(language)
        end

        unless course.published?
          course.published!
          newly_published = true
        end
      end

      return unless newly_published

      request_missing_languages!(course)
    end

    # Riders can join an in-flight import asking for a language the run was
    # never started for (Imports::Create#join! matches on the video and clip
    # language only), and the pipeline fills one language per run. Each of those
    # needs a run of its own, which can only happen once there is a skeleton to
    # hang it on.
    #
    # Hooked to the publish transition rather than to "this request isn't ready
    # yet" deliberately: that transition happens exactly once per course, so a
    # language whose run fails cannot make the finalizer trigger it again on the
    # next callback, and again after that. It waits out its deadline instead.
    def request_missing_languages!(course)
      outstanding_languages(course).each do |language|
        AddCourseTranslationJob.perform_later(progress.id, course.id, language.id)
      end
    end

    def outstanding_languages(course)
      names = ImportRequest.active.where(course_id: course.id).distinct.pluck(:translation_language)

      Language.where(english_name: names).reject { |language| progress.translation_finalized?(language) }
    end

    def fail!(import_request, reason)
      Settlement.fail!(import_request, reason)
      mark_course_failed(import_request.course)
    end

    # Only a course nobody has managed to publish. A course that is already live
    # in another language must not be knocked back to `error` because one
    # translation gave up.
    #
    # Status only — telling the user is Settlement.fail!'s job, which `fail!`
    # has already done for the request that is actually waiting.
    def mark_course_failed(course)
      return if course.nil? || course.published? || course.error?

      course.error!
    rescue => e
      Rails.logger.error "Failed to mark course #{course&.id} as errored: #{e.message}"
    end

    def language_for(import_request)
      Language.find_by(english_name: import_request.translation_language)
    end
  end
end
