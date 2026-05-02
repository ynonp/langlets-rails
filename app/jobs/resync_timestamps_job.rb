class ResyncTimestampsJob < ApplicationJob
  queue_as :default

  def perform(course_id, json_data)
    course = Course.find(course_id)
    medium = course.medium

    Rails.logger.info "Starting ResyncTimestampsJob for course #{course.id} (#{course.slug})"

    phrases = medium.phrases.ordered_by_timestamp.to_a

    if phrases.length != json_data.length
      raise "Phrase count mismatch: medium has #{phrases.length} phrases, JSON has #{json_data.length} entries"
    end

    # First pass: build a hash of phrase.id => new timestamp
    updates = {}
    json_data.each_with_index do |entry, index|
      phrase = phrases[index]
      new_timestamp = entry["timestamp"]

      if new_timestamp.blank?
        raise "Missing timestamp at JSON index #{index}"
      end

      updates[phrase.id] = new_timestamp
      Rails.logger.info "Mapping phrase #{phrase.id} ('#{phrase.text_l1}') => #{new_timestamp}"
    end

    # Second pass: apply all updates
    updates.each do |phrase_id, new_timestamp|
      phrase = Phrase.find(phrase_id)
      old_timestamp = phrase.timestamp
      phrase.update!(timestamp: new_timestamp)
      Rails.logger.info "Updated phrase #{phrase_id} timestamp: #{old_timestamp} => #{new_timestamp}"
    end

    # Update lesson timestamps based on first and last phrase in each lesson
    course.lessons.includes(:activities).find_each do |lesson|
      lesson_phrase_ids = lesson.activities.joins(:phrases).pluck("phrases.id").uniq
      lesson_phrases = phrases.select { |p| lesson_phrase_ids.include?(p.id) }.sort_by(&:timestamp)
      
      if lesson_phrases.any?
        first_timestamp = lesson_phrases.first.timestamp
        last_timestamp = lesson_phrases.last.timestamp
        
        lesson.update!(start_timestamp: first_timestamp, end_timestamp: last_timestamp)
        Rails.logger.info "Updated lesson #{lesson.id} timestamps: #{first_timestamp} => #{last_timestamp}"
      end
    end

    Rails.logger.info "ResyncTimestampsJob completed for course #{course.id}. Updated #{updates.count} phrases."

  rescue => e
    Rails.logger.error "ResyncTimestampsJob failed for course #{course_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
