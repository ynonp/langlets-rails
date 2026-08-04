require "test_helper"

class CreateSongProgressDataFormatTest < ActiveSupport::TestCase
  def legacy_data
    {
      "phrases" => [
        {
          "text_l1" => "hola mundo",
          "text_l2" => "hello world",
          "timestamp" => "00:01.00",
          "words" => [
            { "text" => "hola", "translation" => "hello", "l1_start_index" => 0, "l1_end_index" => 3 },
            { "text" => "mundo", "translation" => "world", "l1_start_index" => 5, "l1_end_index" => 9 }
          ]
        }
      ],
      "lessons" => "# Lesson one\n00:01.00\n00:10.00"
    }
  end

  test "classifies blobs by stamp, then by shape" do
    assert_equal 2, CreateSongProgress::DataFormat.version(nil)
    assert_equal 2, CreateSongProgress::DataFormat.version({})
    assert_equal 1, CreateSongProgress::DataFormat.version(legacy_data)
    assert_equal 1, CreateSongProgress::DataFormat.version({ "phrases_with_token_translations" => { "phrases" => [] } })

    # A neutral mid-pipeline blob (transcribed, never translated) is usable as-is.
    neutral = legacy_data
    neutral["phrases"][0].delete("text_l2")
    neutral["phrases"][0]["words"].each { |w| w.delete("translation") }
    assert_equal 2, CreateSongProgress::DataFormat.version(neutral)

    # An explicit stamp wins over shape, so a run interrupted mid-translate
    # (inline text_l2 present) is not misclassified as legacy.
    assert_equal 2, CreateSongProgress::DataFormat.version(legacy_data.merge("format_version" => 2))
  end

  test "pack_translation moves inline content into the language payload" do
    english = languages(:english)
    data = CreateSongProgress::DataFormat.pack_translation(legacy_data, english)

    assert_equal 2, data["format_version"]
    refute data["phrases"][0].key?("text_l2")
    refute data["phrases"][0]["words"][0].key?("translation")

    payload = data["translations"]["en"]
    assert_equal "English", payload["language_name"]
    assert_equal "hello world", payload["phrases"][0]["text"]
    assert_equal [ "hello", "world" ], payload["phrases"][0]["words"]
    assert_equal data["lessons"], payload["lessons"]
  end

  test "BuildSong refuses a legacy blob" do
    progress = CreateSongProgress.new(
      youtubeurl: "https://www.youtube.com/watch?v=legacy1",
      clip_language: "Spanish",
      data: legacy_data
    )

    assert_raises(CreateSongProgress::LegacyFormatError) do
      CourseBuilder::BuildSong.new(progress, Course.new).call(languages(:english))
    end
  end
end
