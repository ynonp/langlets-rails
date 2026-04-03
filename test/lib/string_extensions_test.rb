require "test_helper"

class StringExtensionsTest < ActiveSupport::TestCase
  test "slug_for_language preserves Arabic characters" do
    arabic_title = "تحدث إلى الكاميرا"
    result = arabic_title.slug_for_language

    assert_equal "تحدث-إلى-الكاميرا", result
  end

  test "slug_for_language handles mixed languages" do
    mixed_title = "Hello تحدث World"
    result = mixed_title.slug_for_language

    assert_equal "hello-تحدث-world", result
  end

  test "slug_for_language handles spaces and special chars" do
    title_with_special = "My Course! @#$ Title"
    result = title_with_special.slug_for_language

    assert_equal "my-course-title", result
  end

  test "slug_for_language returns untitled for blank" do
    result = "".slug_for_language

    assert_equal "untitled", result
  end

  test "slug_for_language limits to 50 characters" do
    long_title = "a" * 100
    result = long_title.slug_for_language

    assert_equal 50, result.length
  end

  test "slug_for_language handles numbers" do
    title = "Course 123 Testing"
    result = title.slug_for_language

    assert_equal "course-123-testing", result
  end

  test "slug_for_language handles Hebrew" do
    hebrew_title = "שלום עולם"
    result = hebrew_title.slug_for_language

    assert_equal "שלום-עולם", result
  end

  test "slug_for_language handles Chinese" do
    chinese_title = "你好世界"
    result = chinese_title.slug_for_language

    assert_equal "你好世界", result
  end
end
