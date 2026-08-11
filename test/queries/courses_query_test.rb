require "test_helper"

class CoursesQueryTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "courses-query@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @spanish = languages(:spanish)
    @hebrew = languages(:hebrew)

    @published = Course.create!(
      name: "Spanish Songs", slug: "spanish-songs", main_media_url: "https://example.com/1",
      user: @user, language: @spanish, status: :published
    )
    @pending = Course.create!(
      name: "Spanish Drafts", slug: "spanish-drafts", main_media_url: "https://example.com/2",
      user: @user, language: @spanish, status: :pending
    )
    @hebrew_course = Course.create!(
      name: "Hebrew Songs", slug: "hebrew-songs", main_media_url: "https://example.com/3",
      user: @user, language: @hebrew, status: :published
    )

    # The query is Channel-scoped, so @user reaches these through their own
    # default Channel rather than because the rows exist.
    [ @published, @pending, @hebrew_course ].each { |course| publish_privately(course) }
  end

  test "excludes courses the caller cannot reach through a channel" do
    stranger = User.create!(
      email: "courses-query-stranger@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    result = CoursesQuery.new(user: stranger, language: "es").call

    assert_empty result[:items]
  end

  test "a nil user sees system channels but not unlisted public channels" do
    assert_empty CoursesQuery.new(user: nil, language: "es").call[:items]

    publish_publicly(@published)
    assert_empty CoursesQuery.new(user: nil, language: "es").call[:items]

    User.create!(email: User::ADMIN_EMAIL, password: "password123", confirmed_at: Time.zone.now)
    publish_system(@published)

    assert_equal [ "spanish-songs" ], CoursesQuery.new(user: nil, language: "es").call[:items].map { |i| i[:slug] }
  end

  test "returns only published courses in the requested language" do
    result = CoursesQuery.new(user: @user, language: "es").call

    assert_equal [ "spanish-songs" ], result[:items].map { |i| i[:slug] }
    item = result[:items].first
    assert_equal "Spanish Songs", item[:name]
    assert_equal "es", item[:language]
    assert_equal 0, item[:lesson_count]
  end

  test "includes url when base_url given" do
    result = CoursesQuery.new(user: @user, language: "es", base_url: "https://langlets.test").call

    assert_equal "https://langlets.test/courses/spanish-songs", result[:items].first[:url]
  end

  test "counts lessons" do
    medium = Medium.create!(url: "https://www.youtube.com/watch?v=cq1", language: @spanish)
    Lesson.create!(course: @published, user: @user, medium: medium, slug: "l1", name: "L1", order: 0)

    result = CoursesQuery.new(user: @user, language: "es").call

    assert_equal 1, result[:items].first[:lesson_count]
  end

  test "raises for unknown language" do
    assert_raises(PaginatedQuery::UnknownLanguageError) do
      CoursesQuery.new(user: @user, language: "zz").call
    end
  end

  test "raises when language missing" do
    assert_raises(ArgumentError) do
      CoursesQuery.new(user: @user, language: nil).call
    end
  end

  test "paginates" do
    result = CoursesQuery.new(user: @user, language: "es", page: 1, per_page: 1).call

    assert_equal 1, result[:items].size
    assert_not result[:has_more]
  end
end
