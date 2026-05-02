require "test_helper"

class ActivitiesHelperTest < ActionView::TestCase
  test "timestamp_to_seconds with MM:SS format" do
    assert_equal 30.0, timestamp_to_seconds("00:30")
    assert_equal 60.0, timestamp_to_seconds("01:00")
    assert_equal 150.5, timestamp_to_seconds("02:30.5")
  end

  test "timestamp_to_seconds with MM:SS:mm format (milliseconds)" do
    assert_equal 30.2, timestamp_to_seconds("00:30:20")
    assert_equal 61.001, timestamp_to_seconds("01:01:001")
    assert_equal 120.5, timestamp_to_seconds("02:00:500")
    assert_equal 30.23, timestamp_to_seconds("00:30:23")
  end

  test "timestamp_to_seconds with zero values" do
    assert_equal 0.0, timestamp_to_seconds("00:00")
    assert_equal 0.0, timestamp_to_seconds("00:00:00")
  end

  test "timestamp_to_seconds with larger minute values" do
    assert_equal 3600.0, timestamp_to_seconds("60:00")
    assert_equal 3660.5, timestamp_to_seconds("61:00.5")
  end
end
