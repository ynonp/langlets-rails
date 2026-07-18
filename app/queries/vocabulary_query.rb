# A user's saved vocabulary (phrase_token_users), newest first, optionally
# filtered to one learning language.
class VocabularyQuery < PaginatedQuery
  def initialize(user:, language: nil, page: 1, per_page: DEFAULT_PER_PAGE)
    @user = user
    @language_code = language.presence
    @page = clamp_page(page)
    @per_page = clamp_per_page(per_page)
  end

  def call
    scope = @user.phrase_token_users
      .joins(phrase_token: :phrase)
      .includes(:language, phrase_token: [ :token_translations, { phrase: [ :l1, :phrase_translations ] } ])
      .order(created_at: :desc, id: :desc)

    if @language_code
      language = find_language!(@language_code)
      scope = scope.where(phrases: { l1_id: language.id })
    end

    rows, has_more = paginate(scope)
    result(rows.map { |saved| serialize(saved) }, has_more)
  end

  private

  def serialize(saved)
    token = saved.phrase_token
    translation = saved.token_translation
    phrase = token.phrase
    phrase_translation = phrase.phrase_translations.find { |row| row.language_id == saved.language_id }
    {
      word: token.original_text,
      translation: translation&.translation,
      language: phrase.l1.iso_name,
      translation_language: saved.language.iso_name,
      context: phrase.text_l1,
      context_translation: phrase_translation&.text,
      saved_at: saved.created_at.iso8601
    }
  end
end
