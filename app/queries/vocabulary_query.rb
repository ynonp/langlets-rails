# A user's saved vocabulary (token_translation_users), newest first, optionally
# filtered to one learning language.
class VocabularyQuery < PaginatedQuery
  def initialize(user:, language: nil, page: 1, per_page: DEFAULT_PER_PAGE)
    @user = user
    @language_code = language.presence
    @page = clamp_page(page)
    @per_page = clamp_per_page(per_page)
  end

  def call
    scope = @user.token_translation_users
      .joins(token_translation: :phrase)
      .includes(token_translation: { phrase: [ :l1, :l2 ] })
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
    token = saved.token_translation
    phrase = token.phrase
    {
      word: token.original_text,
      translation: token.translation,
      language: phrase.l1.iso_name,
      context: phrase.text_l1,
      context_translation: phrase.text_l2,
      saved_at: saved.created_at.iso8601
    }
  end
end
