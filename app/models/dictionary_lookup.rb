# A Dictionary-tab lookup. The learner types anything; the AI decides what
# language it is in and builds one card around a *target-language headword*:
#
#   * typed in the target language  -> headword is the query, explained in the
#     native language ("to_native");
#   * typed in any other language   -> headword is its target-language
#     translation, explained in the native language ("to_target").
#
# Either way the card always teaches a target-language word in the learner's
# native language, which is what makes it saveable as vocabulary.
#
# Text, illustration and pronunciation arrive from separate jobs. The card is
# usable once `status` is ready; the illustration fills in afterwards.
class DictionaryLookup < ApplicationRecord
  MAX_QUERY_LENGTH = 200
  DIRECTIONS = %w[to_native to_target].freeze

  belongs_to :user
  belongs_to :target_language, class_name: "Language"
  belongs_to :native_language, class_name: "Language"
  belongs_to :phrase_token, optional: true

  has_one_attached :illustration
  has_one_attached :pronunciation

  enum :status, { generating: 0, ready: 1, failed: 2 }
  enum :illustration_status, { drawing: 0, drawn: 1, unavailable: 2 }, prefix: :illustration

  validates :query, presence: true, length: { maximum: MAX_QUERY_LENGTH }
  validates :direction, inclusion: { in: DIRECTIONS }, allow_nil: true
  validate :languages_differ

  normalizes :query, with: ->(value) { value.to_s.split.join(" ") }

  after_create_commit -> { GenerateDictionaryEntryJob.perform_later(id) }

  # A card still "generating" after this long lost its job (a deploy, a crash)
  # and is shown as failed rather than polled forever.
  STALE_AFTER = 2.minutes
  # How long the card keeps polling for a pronunciation that may never come.
  PRONUNCIATION_GRACE = 20.seconds

  def to_native? = direction == "to_native"

  def stale? = generating? && created_at < STALE_AFTER.ago
  def failed_or_stale? = failed? || stale?

  # Whether the open card should keep refreshing itself.
  def pending?
    return false if failed_or_stale?
    return true if generating? || illustration_drawing?

    !pronunciation.attached? && updated_at > PRONUNCIATION_GRACE.ago
  end

  # The language the query was written in, for the "Hebrew → Arabic" pill.
  # Falls back to the target language when the query was in it, and to nil
  # when the model reported something outside the supported list.
  def source_language
    return target_language if to_native?

    Language.find_by(iso_name: detected_language) if detected_language.present?
  end

  # The language the card translated *into* — the right-hand side of the pill.
  def result_language
    to_native? ? native_language : target_language
  end

  # Normalized example rows. Each is { sentence:, highlight:, translation:,
  # before:, mark:, after: } where before/mark/after split the sentence around
  # the first occurrence of the highlight (or leave it whole when the model's
  # highlight does not occur verbatim).
  def example_rows
    Array(examples).filter_map do |row|
      row = row.to_h.stringify_keys
      # Whitespace is normalized the same way custom phrases are stored, so the
      # saved span's character offsets match the stored sentence.
      sentence = row["sentence"].to_s.split.join(" ")
      next if sentence.empty?

      highlight = row["highlight"].to_s.split.join(" ")
      offset = highlight.empty? ? nil : sentence.index(highlight)
      {
        sentence: sentence,
        highlight: highlight,
        translation: row["translation"].to_s.strip,
        before: offset ? sentence[0...offset] : sentence,
        mark: offset ? highlight : "",
        after: offset ? sentence[(offset + highlight.length)..] : ""
      }
    end
  end

  def saved? = phrase_token_id.present? && user.phrase_token_users.exists?(phrase_token_id: phrase_token_id)

  # Saves the headword as vocabulary. A saved word is always a span inside a
  # phrase, so the phrase is an example sentence and the span its highlight —
  # preferably an example using the headword exactly as written, else the
  # first one with a usable (possibly inflected) highlight. With no usable example the headword stands
  # as its own one-word phrase. Returns the PhraseTokenUser.
  def save_to_vocabulary!
    raise ActiveRecord::RecordInvalid, self unless ready? && headword.present? && translation.present?

    rows = example_rows.select { |row| row[:mark].present? }
    example = rows.find { |row| row[:mark] == headword } || rows.first
    sentence, span, sentence_translation = if example
      start = example[:before].length
      [ example[:sentence], [ start, start + example[:mark].length - 1 ], example[:translation] ]
    else
      [ headword, [ 0, headword.length - 1 ], nil ]
    end

    saved = PhraseTokenUser.save_custom_span!(
      user: user, sentence: sentence, language: target_language, span: span,
      translation: translation, translation_language: native_language,
      sentence_translation: sentence_translation
    )
    update!(phrase_token: saved.phrase_token)
    saved
  end

  private

  def languages_differ
    return if target_language_id.nil? || native_language_id.nil?
    return unless target_language_id == native_language_id

    errors.add(:target_language, "must differ from the native language")
  end
end
