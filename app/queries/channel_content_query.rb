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
    scope.order(published_at: :desc, id: :desc)
  end
end
