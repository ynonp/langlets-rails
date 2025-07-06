require 'test_helper'

class CreateSongTest < ActiveSupport::TestCase
  def setup
    @create_song = Ai::CreateSong.new("Test Song", "https://youtube.com/watch?v=test", "Hebrew", "English")
  end

  test "find_character_index with Hebrew text - reproduces the bug" do
    # Test case from the user's issue
    text = "היי, אני סוכן בינה מלאכותית"
    tokens = ["היי", "אני", "סוכן", "בינה", "מלאכותית"]
    token_index = 1
    expected_token = "אני"
    
    # Debug: Let's see what map_tokens_with_positions returns
    token_positions = @create_song.send(:map_tokens_with_positions, text)
    puts "Token positions for Hebrew text:"
    token_positions.each_with_index do |pos, idx|
      puts "  #{idx}: '#{pos[:token]}' at #{pos[:start_index]}-#{pos[:end_index]}"
    end
    
    # Debug: Let's check character positions manually
    puts "\nCharacter-by-character breakdown:"
    text.each_char.with_index do |char, idx|
      puts "  #{idx}: '#{char}'"
    end
    
    result = @create_song.send(:find_character_index, text, tokens, token_index, expected_token)
    
    # The expected result should be 5 (where "אני" starts in the text)
    # But according to the bug report, it returns 10
    puts "\nResult: #{result}"
    
    # Manual verification: "אני" should start at index 5 in "היי, אני סוכן בינה מלאכותית"
    # h-i-y-comma-space-a-n-i = positions 0,1,2,3,4,5,6,7
    expected_start_index = 5
    
    # This assertion will likely fail due to the bug
    assert_equal expected_start_index, result, 
      "Expected 'אני' to start at index #{expected_start_index}, but got #{result}"
  end

  test "find_character_index with English text - baseline comparison" do
    # Test with English text to see if the issue is Hebrew-specific
    text = "Hi, I am an artificial intelligence"
    tokens = ["Hi", "I", "am", "an", "artificial", "intelligence"]
    token_index = 1
    expected_token = "I"
    
    # Debug output
    token_positions = @create_song.send(:map_tokens_with_positions, text)
    puts "\nToken positions for English text:"
    token_positions.each_with_index do |pos, idx|
      puts "  #{idx}: '#{pos[:token]}' at #{pos[:start_index]}-#{pos[:end_index]}"
    end
    
    result = @create_song.send(:find_character_index, text, tokens, token_index, expected_token)
    
    # "I" should start at index 4 in "Hi, I am an artificial intelligence"
    expected_start_index = 4
    
    assert_equal expected_start_index, result,
      "Expected 'I' to start at index #{expected_start_index}, but got #{result}"
  end

  test "find_character_index with mixed punctuation and Hebrew" do
    # Test various punctuation scenarios with Hebrew
    text = "שלום! איך אתה?"
    tokens = ["שלום", "איך", "אתה"]
    token_index = 1
    expected_token = "איך"
    
    # Debug output
    token_positions = @create_song.send(:map_tokens_with_positions, text)
    puts "\nToken positions for Hebrew with punctuation:"
    token_positions.each_with_index do |pos, idx|
      puts "  #{idx}: '#{pos[:token]}' at #{pos[:start_index]}-#{pos[:end_index]}"
    end
    
    puts "\nCharacter-by-character breakdown:"
    text.each_char.with_index do |char, idx|
      puts "  #{idx}: '#{char}'"
    end
    
    result = @create_song.send(:find_character_index, text, tokens, token_index, expected_token)
    
    # Manual count: ש-ל-ו-ם-!-space-א-י-ך = "איך" starts at index 6
    expected_start_index = 6
    
    assert_equal expected_start_index, result,
      "Expected 'איך' to start at index #{expected_start_index}, but got #{result}"
  end

  test "map_tokens_with_positions with Hebrew text" do
    # Test the helper method directly
    text = "היי, אני סוכן בינה מלאכותית"
    
    result = @create_song.send(:map_tokens_with_positions, text)
    
    # Expected tokens and their positions
    expected_tokens = [
      { token: "היי", start_index: 0, end_index: 2 },
      { token: "אני", start_index: 5, end_index: 7 },
      { token: "סוכן", start_index: 9, end_index: 12 },
      { token: "בינה", start_index: 14, end_index: 17 },
      { token: "מלאכותית", start_index: 19, end_index: 27 }
    ]
    
    assert_equal expected_tokens.length, result.length,
      "Expected #{expected_tokens.length} tokens, got #{result.length}"
    
    expected_tokens.each_with_index do |expected, idx|
      actual = result[idx]
      assert_equal expected[:token], actual[:token],
        "Token #{idx}: expected '#{expected[:token]}', got '#{actual[:token]}'"
      assert_equal expected[:start_index], actual[:start_index],
        "Token #{idx} start: expected #{expected[:start_index]}, got #{actual[:start_index]}"
    end
  end

  test "tokenize_text with Hebrew" do
    # Test the tokenization method
    text = "היי, אני סוכן בינה מלאכותית"
    
    result = @create_song.send(:tokenize_text, text)
    expected = ["היי", "אני", "סוכן", "בינה", "מלאכותית"]
    
    assert_equal expected, result,
      "Expected tokens #{expected.inspect}, got #{result.inspect}"
  end

  test "find_character_index edge cases" do
    # Test edge cases
    text = "א ב ג"
    tokens = ["א", "ב", "ג"]
    
    # Test first token
    result = @create_song.send(:find_character_index, text, tokens, 0, "א")
    assert_equal 0, result, "First token should start at index 0"
    
    # Test last token
    result = @create_song.send(:find_character_index, text, tokens, 2, "ג")
    assert_equal 4, result, "Last token should start at index 4"
    
    # Test out of bounds
    result = @create_song.send(:find_character_index, text, tokens, 5, "ד")
    assert_equal 0, result, "Out of bounds should return 0"
  end

  test "find_character_index with token mismatch" do
    # Test what happens when expected token doesn't match
    text = "היי, אני סוכן"
    tokens = ["היי", "אני", "סוכן"]
    
    # Try to find a token that doesn't exist at the given index
    result = @create_song.send(:find_character_index, text, tokens, 1, "לא_קיים")
    assert_equal 0, result, "Non-existent token should return 0"
    
    # Try to find a token that exists but not at the given index
    result = @create_song.send(:find_character_index, text, tokens, 0, "אני")
    # This should find "אני" by searching and return its start index
    assert_equal 5, result, "Should find token by searching when index mismatch"
  end

  test "character encoding consistency" do
    # Test that we're handling UTF-8 encoding correctly
    text = "היי, אני סוכן בינה מלאכותית"
        
    # Check specific character positions
    assert_equal "ה", text[0], "First character should be ה"
    assert_equal ",", text[3], "Fourth character should be comma"
    assert_equal " ", text[4], "Fifth character should be space"
    assert_equal "א", text[5], "Sixth character should be א"
    assert_equal "נ", text[6], "Seventh character should be ן"
    assert_equal "י", text[7], "Eighth character should be י"
  end

  test "find_character_index reproduces exact error from log" do
    # Reproduce the exact case from the error log
    text = "היי, אני סוכן בינה מלאכותית"
    tokens = ["היי", "אני", "סוכן", "בינה", "מלאכותית"]
    token_index = 4  # Last token
    expected_token = "מלאכותית"
    
    puts "\n=== REPRODUCING EXACT ERROR FROM LOG ==="
    puts "Text: '#{text}'"
    puts "Token index: #{token_index}"
    puts "Expected token: '#{expected_token}'"
    
    # Debug the token positions
    token_positions = @create_song.send(:map_tokens_with_positions, text)
    puts "\nToken positions:"
    token_positions.each_with_index do |pos, idx|
      puts "  #{idx}: '#{pos[:token]}' at #{pos[:start_index]}-#{pos[:end_index]}"
    end
    
    # Test both start and end index methods
    start_index = @create_song.send(:find_character_index, text, tokens, token_index, expected_token)
    end_index = @create_song.send(:find_character_end_index, text, tokens, token_index, expected_token)
    
    puts "\nResults:"
    puts "Start index: #{start_index}"
    puts "End index: #{end_index}"
    puts "Problem: #{start_index >= end_index ? 'YES - start >= end' : 'NO - indices are valid'}"
    
    # Manual verification of where "מלאכותית" actually is in the text
    manual_start = text.index("מלאכותית")
    manual_end = manual_start + "מלאכותית".length - 1
    puts "\nManual verification:"
    puts "Manual start: #{manual_start}"
    puts "Manual end: #{manual_end}"
    puts "Actual substring: '#{text[manual_start..manual_end]}'"
    
    # The bug: start_index should be 19, not 12
    # And end_index should be 27, not 12
    expected_start = 19
    expected_end = 27
    
    assert_equal expected_start, start_index,
      "Start index should be #{expected_start}, got #{start_index}"
    assert_equal expected_end, end_index,
      "End index should be #{expected_end}, got #{end_index}"
  end

  test "find_character_index reproduces exact bug from log - leonardo hotel" do
    # Reproduce the exact case from the error log
    text = "תודה שהתקשרת למלון לאונרדו. איך אני יכולה לעזור לך היום?"
    tokens = ["תודה", "שהתקשרת", "למלון", "לאונרדו", "איך", "אני", "יכולה", "לעזור", "לך", "היום"]
    token_index = 5  # Looking for "אני"
    expected_token = "אני"
    
    puts "\n=== REPRODUCING EXACT BUG FROM LEONARDO HOTEL LOG ==="
    puts "Text: '#{text}'"
    puts "Token index: #{token_index}"
    puts "Expected token: '#{expected_token}'"
    
    # Debug: show character positions
    puts "\nCharacter-by-character breakdown:"
    text.each_char.with_index do |char, idx|
      puts "  #{idx}: '#{char}'"
    end
    
    # Debug the token positions from map_tokens_with_positions
    token_positions = @create_song.send(:map_tokens_with_positions, text)
    puts "\nToken positions from map_tokens_with_positions:"
    token_positions.each_with_index do |pos, idx|
      puts "  #{idx}: '#{pos[:token]}' at #{pos[:start_index]}-#{pos[:end_index]}"
    end
    
    # Test both start and end index methods
    start_index = @create_song.send(:find_character_index, text, tokens, token_index, expected_token)
    end_index = @create_song.send(:find_character_end_index, text, tokens, token_index, expected_token)
    
    puts "\nResults:"
    puts "Start index: #{start_index}"
    puts "End index: #{end_index}"
    puts "Problem: #{start_index >= end_index ? 'YES - start >= end' : 'NO - indices are valid'}"
    
    # Manual verification of where "אני" actually is in the text
    manual_start = text.index("אני")
    manual_end = manual_start + "אני".length - 1
    puts "\nManual verification:"
    puts "Manual start: #{manual_start}"
    puts "Manual end: #{manual_end}"
    puts "Actual substring: '#{text[manual_start..manual_end]}'"
    
    # According to the log, the actual indexes should be 33-35
    # But the bug shows both start and end as 43
    expected_start = 32
    expected_end = 34
    
    puts "\nExpected from log analysis:"
    puts "Expected start: #{expected_start}"
    puts "Expected end: #{expected_end}"
    puts "Actual text at expected position: '#{text[expected_start..expected_end]}'"
    
    # The test should pass if the bug is fixed
    assert_equal expected_start, start_index,
      "Start index should be #{expected_start}, got #{start_index}"
    assert_equal expected_end, end_index,
      "End index should be #{expected_end}, got #{end_index}"
      
    # Ensure start < end
    assert start_index < end_index, 
      "Start index (#{start_index}) should be less than end index (#{end_index})"
  end

  test "find_character_index bug - token mismatch in production scenario" do
    # The bug happens when there's a token mismatch between what's expected
    # and what's actually found by map_tokens_with_positions
    
    text = "תודה שהתקשרת למלון לאונרדו. איך אני יכולה לעזור לך היום?"
    
    # In production, the tokens come from a different tokenization process
    # which may not exactly match what map_tokens_with_positions finds
    # Let's simulate what happens when the tokenization is slightly different
    
    # What the AI/LLM provides as tokens (production scenario)
    llm_tokens = ["תודה", "שהתקשרת", "למלון", "לאונרדו", "איך", "אני", "יכולה", "לעזור", "לך", "היום"]
    
    # What map_tokens_with_positions actually finds
    actual_token_positions = @create_song.send(:map_tokens_with_positions, text)
    
    puts "\n=== DEBUGGING PRODUCTION TOKEN MISMATCH ==="
    puts "Text: '#{text}'"
    puts "\nLLM/AI provided tokens: #{llm_tokens}"
    puts "Actual tokens found: #{actual_token_positions.map { |t| t[:token] }}"
    
    # Check if there's a mismatch - this is where the bug happens
    llm_tokens.each_with_index do |llm_token, index|
      if index < actual_token_positions.length
        actual_token = actual_token_positions[index][:token]
        if llm_token != actual_token
          puts "MISMATCH at index #{index}: expected '#{llm_token}', got '#{actual_token}'"
        end
      end
    end
    
    # Now let's simulate what happens in the production code
    # when there's a token mismatch
    
    # Try to find "אני" at index 5, but let's say there's a token mismatch
    # that triggers the fallback logic
    token_index = 5
    expected_token = "אני"
    
    puts "\n=== SIMULATING PRODUCTION BUG ==="
    puts "Looking for '#{expected_token}' at index #{token_index}"
    
    # First, let's see what happens with the normal case
    normal_start = @create_song.send(:find_character_index, text, llm_tokens, token_index, expected_token)
    normal_end = @create_song.send(:find_character_end_index, text, llm_tokens, token_index, expected_token)
    
    puts "Normal case - Start: #{normal_start}, End: #{normal_end}"
    
    # Now let's simulate what happens when there's a token mismatch
    # by passing a wrong token that forces the fallback
    wrong_token = "WRONG_TOKEN"
    
    puts "\nSimulating token mismatch by looking for '#{wrong_token}' at index #{token_index}"
    
    mismatch_start = @create_song.send(:find_character_index, text, llm_tokens, token_index, wrong_token)
    mismatch_end = @create_song.send(:find_character_end_index, text, llm_tokens, token_index, wrong_token)
    
    puts "Mismatch case - Start: #{mismatch_start}, End: #{mismatch_end}"
    
    # This is where the bug might happen - if both return 0 or some other value
    if mismatch_start >= mismatch_end
      puts "🐛 BUG REPRODUCED: start (#{mismatch_start}) >= end (#{mismatch_end})"
    else
      puts "✅ No bug in mismatch case"
    end
    
    # Let's also test what happens when we have a partial token match
    # or when the token exists but at a different position
    
    # Test: look for a token that exists but not at the expected index
    puts "\nTesting token that exists but not at expected index:"
    displaced_start = @create_song.send(:find_character_index, text, llm_tokens, 0, expected_token)  # Look for אני at index 0
    displaced_end = @create_song.send(:find_character_end_index, text, llm_tokens, 0, expected_token)
    
    puts "Displaced case - Start: #{displaced_start}, End: #{displaced_end}"
    
    if displaced_start >= displaced_end
      puts "🐛 BUG REPRODUCED: displaced start (#{displaced_start}) >= end (#{displaced_end})"
    else
      puts "✅ No bug in displaced case"
    end
    
    # The actual bug might be in the error handling logic
    # when the token search fails or returns unexpected results
    
    # Let's check what happens when we have empty tokens or nil values
    puts "\nTesting edge cases:"
    
    # Test with empty tokens array
    empty_start = @create_song.send(:find_character_index, text, [], token_index, expected_token)
    empty_end = @create_song.send(:find_character_end_index, text, [], token_index, expected_token)
    
    puts "Empty tokens - Start: #{empty_start}, End: #{empty_end}"
    
    if empty_start >= empty_end
      puts "🐛 BUG REPRODUCED: empty tokens start (#{empty_start}) >= end (#{empty_end})"
    else
      puts "✅ No bug in empty tokens case"
    end
  end

  private

  # Helper method to debug regex behavior
  def debug_regex_scan(text, pattern)
    puts "\nDebugging regex scan for pattern: #{pattern}"
    puts "Text: '#{text}'"
    
    text.scan(pattern) do |match|
      puts "Match: '#{match}' at position #{Regexp.last_match.begin(0)}-#{Regexp.last_match.end(0)}"
    end
  end
end
