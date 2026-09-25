module Api::V1::Native
  class VocabularyController < BaseController
    def index
      scope = user.phrase_token_users.includes(:language, phrase_token: [ :token_translations, :localized_translation,
        { l1_audio_attachment: :blob }, { phrase: [ :l1, :medium, :localized_translation, :phrase_translations,
          { phrase_tokens: [ :token_translations, :localized_translation, { l1_audio_attachment: :blob } ] } ] } ])
      scope = scope.paused if params[:filter] == "paused"
      scope = scope.joins(phrase_token: :phrase).where(phrases: { l1_id: Language.find_by!(iso_name: params[:language]).id }) if params[:language].present?
      if params[:q].present?
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(200))}%"
        scope = scope.joins(phrase_token: :phrase).where(<<~SQL.squish, pattern: pattern)
          phrases.text_l1 ILIKE :pattern OR EXISTS (
            SELECT 1 FROM token_translations WHERE token_translations.phrase_token_id = phrase_tokens.id
            AND token_translations.language_id = phrase_token_users.language_id AND token_translations.translation ILIKE :pattern
          )
        SQL
      end
      render json: page(scope.order(created_at: :desc, id: :desc)) { |row| serializer.vocabulary(row) }
    end
  end
end
