class ReviewLessonBuilder
  MIN_TOKENS_FOR_MATCH = 3
  MIN_TOKENS_FOR_CHAIN = 4
  MAX_TOKENS_PER_ACTIVITY = 15
  MAX_TOKENS_FOR_FLASHCARD = 4
  MAX_TOKENS_FOR_WRITE = 4

  def initialize(user, language_code: nil)
    @user = user
    @language_code = language_code
    @tokens = fetch_tokens
  end

  def fetch_tokens
    tokens = if @language_code
      @user.saved_token_translations_for_language(@language_code)
    else
      @user.saved_token_translations
    end

    tokens.includes(phrase: [ :l1, :l2 ], l1_audio_attachment: :blob).to_a
  end

  def build!
    lesson_name = @language_code ? "Review Words (#{@language_code})" : "Review Words"
    lesson = Lesson.create!(
      user: @user,
      course: nil,
      medium: nil,
      name: lesson_name
    )

    order = 1
    previous_tokens = []

    if @tokens.size >= MIN_TOKENS_FOR_MATCH
      a1 = Activities::FlashcardActivity.create!(lesson: lesson, order: order, user: @user)
      a1_tokens = @tokens.sample([ MAX_TOKENS_FOR_FLASHCARD, @tokens.size ].min)
      a1.token_translations = a1_tokens
      previous_tokens |= a1_tokens
      order += 1
    end

    if @tokens.size >= MIN_TOKENS_FOR_MATCH
      a2 = Activities::MatchTokensActivity.create!(lesson: lesson, order: order, user: @user)
      a2_tokens = @tokens.sample([ MAX_TOKENS_PER_ACTIVITY, @tokens.size ].min)
      a2.token_translations = a2_tokens
      previous_tokens |= a2_tokens
      order += 1
    end

    if @tokens.size >= MIN_TOKENS_FOR_CHAIN
      a3 = Activities::TokensChainActivity.create!(lesson: lesson, order: order, user: @user)
      a3_tokens = @tokens.sample([ MAX_TOKENS_PER_ACTIVITY, @tokens.size ].min)
      a3.token_translations = a3_tokens
      previous_tokens |= a3_tokens
      order += 1
    end

    write_pool = previous_tokens.presence || @tokens
    a4 = Activities::WriteMissingWordActivity.create!(lesson: lesson, order: order, user: @user)
    a4.token_translations = write_pool.sample([ MAX_TOKENS_FOR_WRITE, write_pool.size ].min)

    lesson
  end
end
