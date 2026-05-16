class ResyncTimestampsJob < ApplicationJob
  queue_as :default

  def perform(course_id, json_data)
    course = Course.find(course_id)
    medium = course.medium

    Rails.logger.info "Starting ResyncTimestampsJob for course #{course.id} (#{course.slug})"

    phrases = medium.phrases.ordered_by_timestamp.to_a
    verify_json_data!(json_data, phrases)

    # Update all phrase timestamps in a single pass
    json_data.zip(phrases).each do |entry, phrase|
      phrase.update!(timestamp: entry["timestamp"])
    end

    # Update lesson timestamps based on first and last phrase in each lesson
    course.sync_lesson_timestamps

    Rails.logger.info "ResyncTimestampsJob completed for course #{course.id}. Updated #{phrases.length} phrases."

  rescue => e
    Rails.logger.error "ResyncTimestampsJob failed for course #{course_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  private

  # Expected json_data structure:
  #   [{ "timestamp" => "00:01:23.456", ... }, ...]
  # One entry per phrase, ordered to match medium.phrases.ordered_by_timestamp.
  def verify_json_data!(json_data, phrases)
    if phrases.length != json_data.length
      raise "Phrase count mismatch: medium has #{phrases.length} phrases, JSON has #{json_data.length} entries"
    end

    missing = json_data.each_with_index.select { |entry, _| entry["timestamp"].blank? }
    if missing.any?
      raise "Missing timestamps at JSON indices: #{missing.map(&:last).join(', ')}"
    end
  end
end
