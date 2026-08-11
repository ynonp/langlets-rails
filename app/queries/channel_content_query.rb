class ChannelContentQuery
  def self.courses_visible_to(user)
    courses_in(user ? Channel.visible_to(user) : Channel.visible_to(nil))
  end

  def self.courses_listed_to(user)
    courses_in(Channel.listed_to(user))
  end

  def self.listed_courses
    courses_listed_to(nil)
  end

  def self.courses_in(channels)
    Course.where(id: ChannelItem.where(channel_id: channels.select(:id)).select(:course_id))
  end

  def initialize(user:, language: nil, translation_language: Current.translation_language)
    @user = user
    @language = language
    @translation_language = translation_language
  end

  def items
    items_from(Channel.listed_to(@user), deduplicate: @user.present?)
  end

  private

  def items_from(channels, deduplicate:)
    scope = ChannelItem
      .joins(:channel, :course)
      .merge(channels)
      .merge(Course.published.ready_in(@translation_language))
      .includes(course: [ :language, { course_translations: :language } ])
    scope = scope.where(courses: { language_id: @language.id }) if @language

    # When the same course is published in multiple listed channels (e.g. the
    # user's own channel and the system channel), keep only one row per course.
    # Prefer the user's own channel, then the most recently published item.
    scope = deduplicate_by_course(scope, channels) if deduplicate

    scope.order(published_at: :desc, id: :desc)
  end

  # Returns a subquery that picks the single best ChannelItem id per course_id
  # from the listed set. Own channels win over everything else; ties break on
  # recency.
  def deduplicate_by_course(scope, channels)
    best_per_course = ChannelItem
      .joins(:channel)
      .where(channel_id: channels.select(:id))
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
