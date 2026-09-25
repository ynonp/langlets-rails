# Curated source links, not imported courses. Selecting a card opens the normal
# preview; publication, credit charging and language detection stay in Imports.
class StarterChallengeCatalog
  CATEGORIES = %w[song story tiktok].freeze

  def self.all
    YAML.safe_load_file(Rails.root.join("config/starter_challenge_videos.yml")) || []
  end

  def self.for(language_code, category, catalog: all)
    catalog.select { |entry| entry.fetch("language") == language_code && entry.fetch("category") == category }
      .map do |entry|
        entry.merge("thumbnail_url" => VideoSource.derived_thumbnail_url(entry.fetch("url")))
      end
  end
end
