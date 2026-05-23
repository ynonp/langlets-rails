class AddGermanLanguage < ActiveRecord::Migration[8.0]
  def up
    Language.find_or_create_by!(iso_name: "de") do |lang|
      lang.english_name = "German"
      lang.native_name  = "Deutsch"
      lang.pronunciation_variant_name = "de-DE"
      # rtl defaults to false
    end
  end

  def down
    Language.find_by(iso_name: "de")&.destroy
  end
end
