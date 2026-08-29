module Vocabulary
  # One row of the Vocabulary tab. Wraps a PhraseTokenUser and answers the
  # questions the list, the detail screen and search all ask of it.
  #
  # The context phrase is split into before / mark / after so a view can
  # highlight the saved span in place. That split comes from the token's own
  # character offsets rather than from re-finding the word in the text, which
  # is the whole point of storing vocabulary as a span: two entries for the
  # same word in the same phrase stay distinguishable.
  class Entry
    CUSTOM_SOURCE = "Added by you".freeze

    attr_reader :record

    # sources: optional { medium_id => source label } map, so a list of entries
    # resolves every course name in one query instead of one per row.
    def initialize(record, sources: nil)
      @record = record
      @sources = sources
    end

    delegate :id, :practicing?, :created_at, to: :record

    def token = record.phrase_token
    def phrase = token.phrase
    def language = phrase.l1
    def translation_language = record.language
    def word = token.original_text
    def translation = record.token_translation&.translation
    def practising? = record.practicing?
    def paused? = !record.practicing?

    def context = phrase.text_l1.to_s

    def before
      return context if span.nil?

      context[0...span.first].to_s
    end

    def mark
      return "" if span.nil?

      context[span.first..span.last].to_s
    end

    def after
      return "" if span.nil?

      context[(span.last + 1)..].to_s
    end

    # Where the word came from: the course whose lessons use this medium, or
    # the user's own typing.
    def source
      return CUSTOM_SOURCE if custom?
      return @sources[phrase.medium_id] if @sources&.key?(phrase.medium_id)

      phrase.medium&.lessons&.first&.course&.name
    end

    def custom? = phrase.custom?

    # Everything the list's search box matches against.
    def searchable = [ word, translation, context ].compact.join(" ").downcase

    # Resolves course names for a batch of entries in one query.
    def self.sources_for(records)
      media_ids = records.filter_map { |record| record.phrase_token.phrase.medium_id }.uniq
      return {} if media_ids.empty?

      Lesson.where(medium_id: media_ids).where.not(course_id: nil)
        .includes(:course).order(:order, :id)
        .each_with_object({}) { |lesson, map| map[lesson.medium_id] ||= lesson.course&.name }
    end

    def self.wrap(records)
      sources = sources_for(records)
      records.map { |record| new(record, sources: sources) }
    end

    private

    # Inclusive character offsets of the saved span, or nil when the token's
    # indexes no longer fit the phrase (a phrase repaired after the save).
    def span
      return @span if defined?(@span)

      start_index = token.l1_start_character_index
      end_index = token.l1_end_character_index
      @span =
        if start_index.nil? || end_index.nil? || start_index.negative? || end_index >= context.length || start_index > end_index
          nil
        else
          [ start_index, end_index ]
        end
    end
  end
end
