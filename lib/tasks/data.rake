namespace :data do
  desc "Migrate PhraseToken.similar_sound arrays to normalized SimilarSound rows"
  task migrate_legacy_similar_sounds: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV["DRY_RUN"])
    scope = PhraseToken.all
    scope = scope.where(id: ENV["PHRASE_TOKEN_ID"]) if ENV["PHRASE_TOKEN_ID"].present?

    result = LegacySimilarSoundsMigrator.new(scope:, dry_run:).call
    mode = dry_run ? "Dry run" : "Migration"
    puts "#{mode} complete: #{result.tokens} legacy tokens, " \
         "#{result.created_rows} rows created, #{result.existing_rows} rows already present, " \
         "#{result.cleared_tokens} legacy arrays cleared."
  end
end
