# Records the headword's pronunciation for a Dictionary card's play button.
# Without it the button is simply not rendered.
class PronounceDictionaryEntryJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(lookup_id)
    lookup = DictionaryLookup.find(lookup_id)
    return unless lookup.ready? && lookup.headword.present?
    return if lookup.pronunciation.attached?

    audio = Dictionary::Media.speak(lookup.headword, language: lookup.target_language)
    lookup.pronunciation.attach(io: StringIO.new(audio), filename: "dictionary-#{lookup.id}.mp3",
      content_type: "audio/mpeg")
  rescue Dictionary::Media::Error, Net::ReadTimeout, Net::OpenTimeout, SocketError => error
    Rails.logger.warn("[DictionaryLookup #{lookup_id}] pronunciation failed: #{error.message}")
  end
end
