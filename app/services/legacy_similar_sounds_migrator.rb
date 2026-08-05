class LegacySimilarSoundsMigrator
  Result = Data.define(:tokens, :created_rows, :existing_rows, :cleared_tokens)

  def initialize(scope: PhraseToken.all, dry_run: false)
    @scope = scope
    @dry_run = dry_run
  end

  def call
    totals = { tokens: 0, created_rows: 0, existing_rows: 0, cleared_tokens: 0 }

    legacy_tokens.find_each do |token|
      sounds = Array(token.similar_sound).filter_map { |sound| sound.to_s.strip.presence }.uniq
      next if sounds.empty?

      totals[:tokens] += 1
      start_word_index, end_word_index = word_range(token)

      if @dry_run
        count_dry_run_rows(token, sounds, start_word_index, end_word_index, totals)
        next
      end

      migrate_token!(token, sounds, start_word_index, end_word_index, totals)
    end

    Result.new(**totals)
  end

  private

  def legacy_tokens
    @scope.where("cardinality(phrase_tokens.similar_sound) > 0").includes(phrase: :similar_sounds)
  end

  def migrate_token!(token, sounds, start_word_index, end_word_index, totals)
    created_rows = 0
    existing_rows = 0

    PhraseToken.transaction do
      sounds.each do |replacement_text|
        row = SimilarSound.find_or_create_by!(
          phrase: token.phrase,
          start_word_index:,
          end_word_index:,
          replacement_text:
        )
        row.previously_new_record? ? created_rows += 1 : existing_rows += 1
      end

      token.update_columns(similar_sound: [], updated_at: Time.zone.now)
    end

    totals[:created_rows] += created_rows
    totals[:existing_rows] += existing_rows
    totals[:cleared_tokens] += 1
  end

  def count_dry_run_rows(token, sounds, start_word_index, end_word_index, totals)
    existing = token.phrase.similar_sounds.index_by do |row|
      [ row.start_word_index, row.end_word_index, row.replacement_text ]
    end

    sounds.each do |replacement_text|
      key = [ start_word_index, end_word_index, replacement_text ]
      existing.key?(key) ? totals[:existing_rows] += 1 : totals[:created_rows] += 1
    end
  end

  def word_range(token)
    if token.word_index?
      return [ token[:l1_start_index], token[:l1_end_index] ]
    end

    ranges = token.phrase.text_l1.to_enum(:scan, /\S+/).map do
      match = Regexp.last_match
      (match.begin(0)..match.end(0) - 1)
    end
    start_index = ranges.index { |range| range.end >= token[:l1_start_index] }
    end_index = ranges.rindex { |range| range.begin <= token[:l1_end_index] }

    if start_index.nil? || end_index.nil? || start_index > end_index
      raise ArgumentError, "Cannot map PhraseToken #{token.id} indexes to words"
    end

    [ start_index, end_index ]
  end
end
