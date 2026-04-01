require "test_helper"

class CreateSongProgressTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "add_lessons#match_lesson_data_to_prompt with server timestamps" do
    p = CreateSongProgress.new
    user_data = <<~END
00:08.00 We were good
00:10.00 we were gold
00:12.50 Kind of dream
00:13.00 that can't be sold
00:16.00 We were right
00:18.00 'til we weren't
00:20.00 Built a home
00:21.25 and watched it burn
00:25.00 I didn't wanna leave you
00:26.00 I didn't wanna lie
00:29.50 Started to cry
00:30.00 but then remembered I
00:34.00 I can buy myself flowers
00:37.00 Write my name in the sand
00:41.00 Talk to myself for hours
00:45.00 Say things you don't understand
00:50.00 I can take myself dancing
00:53.00 And I can hold my own hand
00:57.00 Yeah, I can love me better than
01:01.00 you can
    END

    llm_response = <<~END
# The Golden Dream
00:08.00 We were good
00:10.00 we were gold
00:12.50 Kind of dream
00:13.00 that can't be sold
00:16.00 We were right
00:18.00 'til we weren't
00:20.00 Built a home
00:21.25 and watched it burn

# The Turning Point
00:25.00 I didn't wanna leave you
00:26.00 I didn't wanna lie
00:29.50 Started to cry
00:30.00 but then remembered I

# The "I Can" Anthem
00:34.00 I can buy myself flowers
00:37.00 Write my name in the sand
00:41.00 Talk to myself for hours
00:45.00 Say things you don't understand
00:50.00 I can take myself dancing
00:53.00 And I can hold my own hand
00:57.00 Yeah, I can love me better than
01:01.00 you can
    END

    lessons = p.send(:match_lesson_data_to_prompt, user_data, llm_response)
    assert lessons.strip == llm_response.strip
  end

  test "add_lessons#match_lesson_data_to_prompt without llm timestamps" do
    p = CreateSongProgress.new
    user_data = <<~END
00:08.00 We were good
00:10.00 we were gold
00:12.50 Kind of dream
00:13.00 that can't be sold
00:16.00 We were right
00:18.00 'til we weren't
00:20.00 Built a home
00:21.25 and watched it burn
00:25.00 I didn't wanna leave you
00:26.00 I didn't wanna lie
00:29.50 Started to cry
00:30.00 but then remembered I
00:34.00 I can buy myself flowers
00:37.00 Write my name in the sand
00:41.00 Talk to myself for hours
00:45.00 Say things you don't understand
00:50.00 I can take myself dancing
00:53.00 And I can hold my own hand
00:57.00 Yeah, I can love me better than
01:01.00 you can
    END

    llm_response = <<~END
# The Golden Dream
We were good
we were gold
Kind of dream
that can't be sold
We were right
'til we weren't
Built a home
and watched it burn

# The Turning Point
I didn't wanna leave you
I didn't wanna lie
Started to cry
but then remembered I

# The "I Can" Anthem
I can buy myself flowers
Write my name in the sand
Talk to myself for hours
Say things you don't understand
I can take myself dancing
And I can hold my own hand
Yeah, I can love me better than
you can
    END

    expected = <<~END
# The Golden Dream
00:08.00 We were good
00:10.00 we were gold
00:12.50 Kind of dream
00:13.00 that can't be sold
00:16.00 We were right
00:18.00 'til we weren't
00:20.00 Built a home
00:21.25 and watched it burn

# The Turning Point
00:25.00 I didn't wanna leave you
00:26.00 I didn't wanna lie
00:29.50 Started to cry
00:30.00 but then remembered I

# The "I Can" Anthem
00:34.00 I can buy myself flowers
00:37.00 Write my name in the sand
00:41.00 Talk to myself for hours
00:45.00 Say things you don't understand
00:50.00 I can take myself dancing
00:53.00 And I can hold my own hand
00:57.00 Yeah, I can love me better than
01:01.00 you can
    END


    lessons = p.send(:match_lesson_data_to_prompt, user_data, llm_response)
    assert lessons.strip == expected.strip
  end
end
