require "test_helper"

class StarterChallengeCatalogTest < ActiveSupport::TestCase
  setup do
    Language.find_or_create_by!(iso_name: "de") do |language|
      language.english_name = "German"
      language.native_name = "Deutsch"
      language.pronunciation_variant_name = "de-DE"
    end
  end
  test "every supported language has song and story choices" do
    Language.pluck(:iso_name).each do |code|
      assert_operator StarterChallengeCatalog.for(code, "tiktok").size, :>=, 1, "#{code} needs a TikTok choice"
      %w[song story].each do |category|
        assert_operator StarterChallengeCatalog.for(code, category).size, :>=, 2, "#{code}/#{category} needs choices"
      end
    end
  end

  test "entries have supported categories languages unique parseable source URLs and provenance" do
    catalog = StarterChallengeCatalog.all
    assert_equal catalog.size, catalog.map { |entry| entry.fetch("url") }.uniq.size
    catalog.each do |entry|
      assert_includes Language.pluck(:iso_name), entry.fetch("language")
      assert_includes StarterChallengeCatalog::CATEGORIES, entry.fetch("category")
      assert_equal "https", URI(entry.fetch("url")).scheme
      assert_match %r{\Ahttps://}, entry.fetch("research_url")
      assert Date.iso8601(entry.fetch("reviewed_on"))
      assert_equal "public_listing", entry.fetch("verification")
      if entry.fetch("category") == "tiktok"
        assert_match %r{\Ahttps://www\.tiktok\.com/@[\w.]+/video/\d+\z}, entry.fetch("url")
      else
        assert_match %r{\Ahttps://www\.youtube\.com/watch\?v=[\w-]{11}\z}, entry.fetch("url")
      end
    end
  end

  test "selection isolates both language and category without modifying catalog" do
    catalog = StarterChallengeCatalog.all
    entries = StarterChallengeCatalog.for("fr", "song", catalog: catalog)
    assert entries.all? { |entry| entry["language"] == "fr" && entry["category"] == "song" && entry["thumbnail_url"].present? }
    assert catalog.none? { |entry| entry.key?("thumbnail_url") }
    assert_empty StarterChallengeCatalog.for("missing", "tiktok", catalog: catalog)
  end
end
