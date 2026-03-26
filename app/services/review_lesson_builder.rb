class ReviewLessonBuilder
  MIN_TOKENS_FOR_MATCH = 3
  MIN_TOKENS_FOR_CHAIN = 4
  MAX_TOKENS_PER_ACTIVITY = 15
  MAX_TOKENS_FOR_WRITE = 10

  def initialize(user)
    @user = user
    @tokens = user.saved_token_translations
                  .includes(phrase: [:l1, :l2], l1_audio_attachment: :blob)
                  .to_a
  end

  def build!
    lesson = Lesson.create!(
      user: @user,
      course: nil,
      medium: nil,
      name: "Review Words"
    )

    order = 1

    if @tokens.size >= MIN_TOKENS_FOR_MATCH
      a1 = Activities::FlashcardActivity.create!(lesson: lesson, order: order, user: @user)
      a1.token_translations = @tokens.sample([MAX_TOKENS_PER_ACTIVITY, @tokens.size].min)
      order += 1
    end

    if @tokens.size >= MIN_TOKENS_FOR_MATCH
      a2 = Activities::MatchTokensActivity.create!(lesson: lesson, order: order, user: @user)
      a2.token_translations = @tokens.sample([MAX_TOKENS_PER_ACTIVITY, @tokens.size].min)
      order += 1
    end

    if @tokens.size >= MIN_TOKENS_FOR_CHAIN
      a3 = Activities::TokensChainActivity.create!(lesson: lesson, order: order, user: @user)
      a3.token_translations = @tokens.sample([MAX_TOKENS_PER_ACTIVITY, @tokens.size].min)
      order += 1
    end

    a4 = Activities::WriteMissingWordActivity.create!(lesson: lesson, order: order, user: @user)
    a4.token_translations = @tokens.sample([MAX_TOKENS_FOR_WRITE, @tokens.size].min)

    lesson
  end
end
