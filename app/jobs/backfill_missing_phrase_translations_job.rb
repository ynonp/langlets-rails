class BackfillMissingPhraseTranslationsJob < ApplicationJob
  queue_as :default

  def perform
    # Saved items pin the target language. Do not infer it from user preferences,
    # and include paused items: their example sentences still need translations.
    missing = PhraseTokenUser.joins(phrase_token: :phrase)
      .where.not(phrases: { user_id: nil })
      .where(<<~SQL)
        NOT EXISTS (
          SELECT 1 FROM phrase_translations
          WHERE phrase_translations.phrase_id = phrases.id
            AND phrase_translations.language_id = phrase_token_users.language_id
        )
      SQL

    enqueued_count = 0
    Phrase.where(id: missing.select("phrases.id")).find_each do |phrase|
      missing.where(phrases: { id: phrase.id }).distinct.pluck(:language_id).each do |language_id|
        TranslateCustomPhraseJob.perform_later(phrase.id, language_id)
        enqueued_count += 1
      end
    end

    Rails.logger.info("BackfillMissingPhraseTranslationsJob enqueued #{enqueued_count} missing phrase translations")
    enqueued_count
  end
end
