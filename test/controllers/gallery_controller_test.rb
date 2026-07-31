require "test_helper"

class GalleryControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @language = languages(:english)
    @other_language = languages(:french)
    @user = User.create!(
      email: "gallery-owner@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @public_channel = @user.default_channel
    @public_channel.update!(visibility: :public)
  end

  test "is empty when all channels are private" do
    create_course("Private Course", @language)
    @public_channel.update!(visibility: :private)

    get gallery_url

    assert_response :success
    assert_select ".gallery-card", count: 0
  end

  test "signed-in owners see courses from their private channels" do
    course = create_course("Owned Private Course", @language)
    @public_channel.update!(visibility: :private)
    sign_in @user

    get gallery_url

    assert_response :success
    assert_select ".gallery-card h2", text: course.name
  end

  test "signed-in gallery includes the user menu" do
    sign_in @user

    get gallery_url(lang: @language.iso_name)

    assert_response :success
    assert_select "[data-controller='profile-menu']", count: 1
    assert_select "a", text: "Profile"
  end

  test "shows courses and playlists in one paginated grid" do
    course = create_course("Gallery Course", @language)
    playlist = Playlist.create!(name: "Gallery Playlist", slug: "gallery-playlist", published: true)
    playlist.courses << course

    get gallery_url

    assert_response :success
    assert_select ".gallery-card", count: 2
    assert_select ".gallery-card-kind", text: "Course"
    assert_select ".gallery-card-kind-playlist", text: "Playlist"
    assert_select ".gallery-card h2.app-clamp-2", text: "Gallery Course"
    assert_select "h1", text: "Start A Language Practice"
    assert_select "a", text: "Back home", count: 0
    assert_select ".gallery-pill-label", count: 0
    assert_select ".gallery-pills", count: 1
  end

  test "filters by one selected content type and language" do
    english_course = create_course("English Search Match", @language)
    french_course = create_course("French Search Match", @other_language)
    english_playlist = Playlist.create!(name: "English Collection", slug: "english-collection", published: true)
    french_playlist = Playlist.create!(name: "French Collection", slug: "french-collection", published: true)
    english_playlist.courses << english_course
    french_playlist.courses << french_course

    get gallery_url(types: [ "playlists" ], languages: [ "en" ])

    assert_response :success
    assert_select ".gallery-card", count: 1
    assert_select "h2", text: "English Collection"
    assert_select "h2", text: "French Collection", count: 0
    assert_select ".gallery-card-kind", text: "Course", count: 0
  end

  test "combines multiple content types and languages" do
    english_course = create_course("English Course", @language)
    french_course = create_course("French Course", @other_language)
    english_playlist = Playlist.create!(name: "English Playlist", slug: "multi-english", published: true)
    french_playlist = Playlist.create!(name: "French Playlist", slug: "multi-french", published: true)
    english_playlist.courses << english_course
    french_playlist.courses << french_course

    get gallery_url(
      types: [ "courses", "playlists" ],
      languages: [ @language.iso_name, @other_language.iso_name ]
    )

    assert_response :success
    assert_select ".gallery-card", count: 4
  end

  test "only shows the result count and clear action while searching" do
    create_course("Needle Course", @language)

    get gallery_url
    assert_select ".gallery-summary", count: 0

    get gallery_url(search: "needle")
    assert_select ".gallery-summary", text: /1 result/
    assert_select ".gallery-clear", text: "Clear Search"
  end

  test "renders immediate-search controls and replaces results with a turbo stream" do
    create_course("Turbo Course", @language)

    get gallery_url
    assert_select "[data-controller='gallery-filters']", count: 1
    assert_select "form[data-gallery-filters-target='form'][data-turbo-stream='true']", count: 1
    assert_select "input[type='search'][data-action='input->gallery-filters#search']", count: 1
    assert_select "input.gallery-pill-input[data-action='change->gallery-filters#submit']", minimum: 2

    get gallery_url(search: "turbo"), headers: { "Accept" => Mime[:turbo_stream].to_s }

    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    assert_select "turbo-stream[action='replace'][target='gallery-results']", count: 1
    assert_select "turbo-stream .gallery-summary", text: /1 result/
  end

  test "paginates at sixteen entries" do
    17.times { |index| create_course("Paged Course #{index}", @language) }

    get gallery_url

    assert_response :success
    assert_select ".gallery-card", count: 16
    assert_select ".gallery-pagination"
  end

  test "preloads card data without per-card selects" do
    8.times { |index| create_course("Query Course #{index}", @language) }
    4.times do |index|
      playlist = Playlist.create!(name: "Query Playlist #{index}", slug: "query-playlist-#{index}", published: true)
      playlist.courses << Course.published.offset(index).first
    end

    queries = capture_selects { get gallery_url }

    assert_response :success
    assert_operator queries.grep(/FROM "course_translations"/).size, :<=, 1
    assert_operator queries.grep(/FROM "languages"/).size, :<=, 3
    assert_operator queries.grep(/FROM "lessons"/).size, :<=, 1
    assert_operator queries.grep(/FROM "courses_playlists"/).size, :<=, 2
  end

  private

  def create_course(name, language)
    course = Course.create!(
      name: name,
      slug: name.parameterize,
      main_media_url: "https://www.youtube.com/watch?v=#{SecureRandom.hex(6)}",
      language: language,
      user: @user,
      status: :published
    )
    @public_channel.publish!(course)
    course
  end

  def capture_selects
    queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == "SCHEMA" || payload[:cached]

      queries << payload[:sql].squish if payload[:sql].to_s.lstrip.start_with?("SELECT")
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end
end
