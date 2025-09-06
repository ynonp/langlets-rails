require 'test_helper'

module CourseBuilder
  class BuildSongTest < ActiveSupport::TestCase
    test "validates no overlapping tokens" do
      # Create a mock phrase
      phrase = Struct.new(:text_l1).new("I didn't know how")
      
      # Test overlapping tokens - should raise exception
      overlapping_data = [
        {
          l1_start: 0,
          l1_end: 2,
          translation: "ידעתי",
          l2_start: nil,
          l2_end: nil
        },
        {
          l1_start: 1,
          l1_end: 1,
          translation: "לא",
          l2_start: nil,
          l2_end: nil
        }
      ]
      
      builder = BuildSong.new(nil, nil)
      
      assert_raises(ArgumentError, "Expected ArgumentError for overlapping tokens") do
        builder.send(:validate_no_overlapping_tokens!, overlapping_data, phrase)
      end
      
      # Test non-overlapping tokens - should not raise exception
      non_overlapping_data = [
        {
          l1_start: 0,
          l1_end: 0,
          translation: "אני",
          l2_start: nil,
          l2_end: nil
        },
        {
          l1_start: 2,
          l1_end: 2,
          translation: "יודע",
          l2_start: nil,
          l2_end: nil
        }
      ]
      
      assert_nothing_raised("Non-overlapping tokens should not raise exception") do
        builder.send(:validate_no_overlapping_tokens!, non_overlapping_data, phrase)
      end
    end

    test "tokens_overlap? correctly detects overlapping ranges" do
      builder = BuildSong.new(nil, nil)
      
      # Test overlapping cases
      token1 = { l1_start: 0, l1_end: 2 }
      token2 = { l1_start: 1, l1_end: 3 }
      assert builder.send(:tokens_overlap?, token1, token2), "Should detect overlap"
      
      # Test contained token
      token3 = { l1_start: 0, l1_end: 3 }
      token4 = { l1_start: 1, l1_end: 2 }
      assert builder.send(:tokens_overlap?, token3, token4), "Should detect contained token"
      
      # Test non-overlapping adjacent tokens
      token5 = { l1_start: 0, l1_end: 1 }
      token6 = { l1_start: 2, l1_end: 3 }
      assert_not builder.send(:tokens_overlap?, token5, token6), "Adjacent tokens should not overlap"
      
      # Test identical tokens
      token7 = { l1_start: 1, l1_end: 2 }
      token8 = { l1_start: 1, l1_end: 2 }
      assert builder.send(:tokens_overlap?, token7, token8), "Identical tokens should overlap"
    end

    test "empty token data does not raise exception" do
      phrase = Struct.new(:text_l1).new("test phrase")
      builder = BuildSong.new(nil, nil)
      
      assert_nothing_raised("Empty token data should not raise exception") do
        builder.send(:validate_no_overlapping_tokens!, [], phrase)
      end
    end
  end
end