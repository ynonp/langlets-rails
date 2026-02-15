require "test_helper"

class CreateSongProgressesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @progress = CreateSongProgress.create!(
      youtubeurl: 'https://www.youtube.com/watch?v=test123',
      clip_language: 'English',
      translation_language: 'Spanish',
      data: {
        'phrases' => [
          {
            'id' => 'phrase_1',
            'text_l1' => 'Hello world',
            'timestamp' => '00:01'
          }
        ]
      }
    )
  end

  test "should get show" do
    get create_song_progress_url(@progress)
    assert_response :success
    assert_select 'h1', text: 'Creating Course from YouTube Video'
  end

  test "should display progress steps" do
    get create_song_progress_url(@progress)
    assert_response :success
    assert_select 'h2', text: 'Creation Progress'
  end

  test "should display YouTube embed" do
    get create_song_progress_url(@progress)
    assert_response :success
    assert_select 'iframe'
  end
end
