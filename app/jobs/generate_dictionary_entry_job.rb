# Writes a Dictionary card's text, then hands off the illustration and the
# pronunciation, which are slower and optional. The card becomes usable the
# moment this job marks it ready.
class GenerateDictionaryEntryJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(lookup_id)
    lookup = DictionaryLookup.find(lookup_id)
    return unless lookup.generating?

    result = Dictionary::EntryGenerator.call(lookup)
    lookup.update!(result.attributes.merge(status: :ready))

    IllustrateDictionaryEntryJob.perform_later(lookup.id)
    PronounceDictionaryEntryJob.perform_later(lookup.id)
  rescue StandardError => error
    raise if error.is_a?(ActiveRecord::RecordNotFound)

    Rails.logger.error("[DictionaryLookup #{lookup_id}] generation failed: #{error.class}: #{error.message}")
    lookup&.update_columns(status: DictionaryLookup.statuses[:failed],
      illustration_status: DictionaryLookup.illustration_statuses[:unavailable],
      failure_reason: error.message.first(500), updated_at: Time.zone.now)
  end
end
