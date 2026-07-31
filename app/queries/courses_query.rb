# Published courses in a given language (ISO code), newest first.
#
# `user` is the token's resource owner. It is required rather than defaulting
# to nil-means-everything: this query feeds the bearer API and the MCP tool,
# both of which hand out course URLs, and an unscoped listing there would
# enumerate every user's private imports. Passing nil is still meaningful and
# explicit — it yields the public-Channel catalogue.
class CoursesQuery < PaginatedQuery
  def initialize(language:, user:, page: 1, per_page: DEFAULT_PER_PAGE, base_url: nil)
    @language_code = language.presence
    @user = user
    @page = clamp_page(page)
    @per_page = clamp_per_page(per_page)
    @base_url = base_url
  end

  def call
    raise ArgumentError, "language is required" if @language_code.nil?
    language = find_language!(@language_code)

    scope = ChannelContentQuery.courses_visible_to(@user)
                               .published
                               .ready_in(Current.translation_language)
                               .where(language: language)
                               .order(created_at: :desc)
    rows, has_more = paginate(scope)

    lesson_counts = Lesson.where(course_id: rows.map(&:id)).group(:course_id).count
    result(rows.map { |course| serialize(course, language, lesson_counts) }, has_more)
  end

  private

  def serialize(course, language, lesson_counts)
    {
      id: course.id,
      name: course.localized_name,
      slug: course.slug,
      language: language.iso_name,
      lesson_count: lesson_counts.fetch(course.id, 0),
      url: @base_url ? "#{@base_url}/courses/#{course.slug}" : nil
    }.compact
  end
end
