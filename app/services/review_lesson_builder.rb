class ReviewLessonBuilder
  MIN_TOKENS_FOR_MATCH = 3
  MIN_TOKENS_FOR_CHAIN = 4
  MAX_TOKENS_PER_ACTIVITY = 15
  MAX_TOKENS_FOR_FLASHCARD = 4
  MAX_TOKENS_FOR_WRITE = 4

  def initialize(user, language_code: nil)
    @user = user
    @language_code = language_code
    @language = Language.find_by(iso_name: language_code) if language_code
    @tokens = fetch_tokens
  end

  def fetch_tokens
    rows = @user.phrase_token_users
      .includes(:language, phrase_token: [ :token_translations, { phrase: [ :l1, :phrase_translations ] }, { l1_audio_attachment: :blob } ])
    if @language_code
      return [] unless @language
      rows = rows.joins(phrase_token: :phrase).where(phrases: { l1_id: @language.id })
    end

    rows.map do |saved|
      saved.phrase_token.tap { |token| token.resolved_translation = saved.token_translation }
    end
  end

  def create_pending!
    lesson_name = @language_code ? "Review Words (#{@language_code})" : "Review Words"
    Lesson.create!(
      user: @user,
      course: nil,
      medium: nil,
      name: lesson_name,
      review_language: @language,
      review_build_status: :pending
    )
  end

  def build!(lesson: nil)
    lesson ||= create_pending!

    Lesson.transaction do
      order = 1
      previous_tokens = []

      if @tokens.size >= MIN_TOKENS_FOR_MATCH
        a1 = Activities::FlashcardActivity.create!(lesson: lesson, order: order, user: @user)
        a1_tokens = @tokens.sample([ MAX_TOKENS_FOR_FLASHCARD, @tokens.size ].min)
        a1.phrase_tokens = a1_tokens
        previous_tokens |= a1_tokens
        order += 1
      end

      if @tokens.size >= MIN_TOKENS_FOR_MATCH
        a2 = Activities::MatchTokensActivity.create!(lesson: lesson, order: order, user: @user)
        a2_tokens = @tokens.sample([ MAX_TOKENS_PER_ACTIVITY, @tokens.size ].min)
        a2.phrase_tokens = a2_tokens
        previous_tokens |= a2_tokens
        order += 1
      end

      if @tokens.size >= MIN_TOKENS_FOR_CHAIN
        a3 = Activities::TokensChainActivity.create!(lesson: lesson, order: order, user: @user)
        a3_tokens = @tokens.sample([ MAX_TOKENS_PER_ACTIVITY, @tokens.size ].min)
        a3.phrase_tokens = a3_tokens
        previous_tokens |= a3_tokens
        order += 1
      end

      write_pool = previous_tokens.presence || @tokens
      a4 = Activities::WriteMissingWordActivity.create!(lesson: lesson, order: order, user: @user)
      a4.phrase_tokens = write_pool.sample([ MAX_TOKENS_FOR_WRITE, write_pool.size ].min)
      lesson.update!(review_build_status: :ready, review_build_error: nil)
    end

    lesson
  end
end
