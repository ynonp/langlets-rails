# Base for the agent-facing queries (REST API + MCP tools). Results share the
# shape { items:, page:, per_page:, has_more: }.
class PaginatedQuery
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  class UnknownLanguageError < StandardError
    def initialize(code)
      super("Unknown language '#{code}'. Use an ISO language code like 'en' or 'es'.")
    end
  end

  private

  def clamp_page(page)
    [ page.to_i, 1 ].max
  end

  def clamp_per_page(per_page)
    value = per_page.to_i
    value < 1 ? DEFAULT_PER_PAGE : [ value, MAX_PER_PAGE ].min
  end

  def find_language!(code)
    Language.find_by(iso_name: code) || raise(UnknownLanguageError, code)
  end

  # Fetches one extra row so has_more is exact without a COUNT query.
  def paginate(scope)
    rows = scope.limit(@per_page + 1).offset((@page - 1) * @per_page).to_a
    [ rows.first(@per_page), rows.size > @per_page ]
  end

  def result(items, has_more)
    { items: items, page: @page, per_page: @per_page, has_more: has_more }
  end
end
