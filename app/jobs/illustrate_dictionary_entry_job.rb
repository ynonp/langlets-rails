# Draws a Dictionary card's illustration. Also run again by "Regenerate
# illustration". A failure leaves the card without a picture rather than
# failing the lookup — the picture is decoration, the text is the entry.
class IllustrateDictionaryEntryJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(lookup_id)
    lookup = DictionaryLookup.find(lookup_id)
    return unless lookup.ready?

    scene = lookup.illustration_prompt.presence || "#{lookup.headword} (#{lookup.translation})"
    image = Dictionary::Media.illustrate(scene)
    lookup.illustration.attach(io: StringIO.new(image), filename: "dictionary-#{lookup.id}.webp",
      content_type: "image/webp")
    lookup.illustration_drawn!
  rescue Dictionary::Media::Error, Net::ReadTimeout, Net::OpenTimeout, SocketError => error
    Rails.logger.warn("[DictionaryLookup #{lookup_id}] illustration failed: #{error.message}")
    lookup&.illustration_unavailable!
  end
end
