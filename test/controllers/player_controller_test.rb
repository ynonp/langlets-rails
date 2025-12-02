require "test_helper"

class PlayerControllerTest < ActionDispatch::IntegrationTest
  setup do
    @l1 = languages(:spanish)
    @l2 = languages(:english)

    @user = User.create!(
      email: "player@example.com",
      password: "password123",
      confirmed_at: Time.current
    )

    @medium = Medium.create!(
      url: "https://www.youtube.com/watch?v=abcd1234567",
      language: @l1
    )

    @course = Course.create!(
      name: "A Dios Le Pido",
      slug: "a-dios-le-pido",
      main_media_url: @medium.url,
      language: @l1,
      user: @user,
      status: :published
    )

    Lesson.create!(
      name: "Verse 1",
      slug: "a-dios-le-pido0",
      order: 0,
      user: @user,
      medium: @medium,
      course: @course
    )

    @phrase_one = Phrase.create!(
      text_l1: "Hola mundo",
      text_l2: "Hello world",
      timestamp: "00:00",
      medium: @medium,
      l1: @l1,
      l2: @l2
    )

    @phrase_two = Phrase.create!(
      text_l1: "Dime por qué",
      text_l2: "Tell me why",
      timestamp: "00:05",
      medium: @medium,
      l1: @l1,
      l2: @l2
    )

    TokenTranslation.create!(
      phrase: @phrase_one,
      l1_start_index: 0,
      l1_end_index: 0,
      l2_start_index: 0,
      l2_end_index: 0,
      translation: "Hello"
    )

    TokenTranslation.create!(
      phrase: @phrase_two,
      l1_start_index: 0,
      l1_end_index: 0,
      l2_start_index: 0,
      l2_end_index: 0,
      translation: "Tell"
    )
  end

  test "shows course player with lyrics and vocabulary" do
    get play_course_path(@course.slug)

    assert_response :success
    assert_select "h1", text: @course.name
    assert_includes response.body, "Hola mundo"
    assert_includes response.body, "Download CSV"
  end

  test "downloads vocabulary csv" do
    get play_course_path(@course.slug, format: :csv)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.body, "Word,Translation,Phrase,Timestamp"
    assert_includes response.body, "Hola mundo"
  end
end
