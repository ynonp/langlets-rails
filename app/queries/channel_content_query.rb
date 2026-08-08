class ChannelContentQuery
  def self.courses_visible_to(user)
    channels = user ? Channel.visible_to(user) : Channel.where(visibility: Channel.visibilities[:public])

    Course.where(
      id: ChannelItem.where(channel_id: channels.select(:id))
        .select(:course_id)
    )
  end

  def self.public_courses
    courses_visible_to(nil)
  end

  def initialize(user:, language: nil, translation_language: Current.translation_language)
    @user = user
    @language = language
    @translation_language = translation_language
  end

  def items
    scope = ChannelItem
      .joins(:channel, :course)
      .merge(Channel.visible_to(@user))
      .merge(Course.published.ready_in(@translation_language))
      .includes(:channel, course: [ :language, { course_translations: :language } ])
    scope = scope.where(courses: { language_id: @language.id }) if @language

    # When the same course is published in multiple visible channels (e.g. the
    # user's own channel and a public channel), keep only one row per course.
    # Prefer the user's own channel, then the most recently published item.
    scope = deduplicate_by_course(scope) if @user

    scope.order(published_at: :desc, id: :desc)
  end

  private

  # Returns a subquery that picks the single best ChannelItem id per course_id
  # from the visible set. Own channels win over everything else; ties break on
  # recency.
  def deduplicate_by_course(scope)
    visible_ids = Channel.visible_to(@user).select(:id)

    best_per_course = ChannelItem
      .joins(:channel)
      .where(channel_id: visible_ids)
      .select("DISTINCT ON (channel_items.course_id) channel_items.id")
      .order(
        :course_id,
        Arel.sql("CASE WHEN channels.user_id = #{@user.id} AND channels.type IS NULL THEN 0 ELSE 1 END"),
        published_at: :desc,
        id: :desc
      )

    scope.where(id: best_per_course)
  end
end
