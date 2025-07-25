# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create scripts first (only for languages we're seeding)
latin_script = Script.find_or_create_by!(code: 'Latn') do |script|
  script.name = 'Latin'
end

hebrew_script = Script.find_or_create_by!(code: 'Hebr') do |script|
  script.name = 'Hebrew'
end

arabic_script = Script.find_or_create_by!(code: 'Arab') do |script|
  script.name = 'Arabic'
end

# Create languages with their default scripts
l_en = Language.find_or_create_by!(iso_name: 'en') do |lang|
  lang.english_name = 'English'
  lang.native_name = 'English'
  lang.pronunciation_variant_name = 'en-US'
  lang.default_script = latin_script
end

l_he = Language.find_or_create_by!(iso_name: 'he') do |lang|
  lang.english_name = 'Hebrew'
  lang.native_name = 'עברית'
  lang.pronunciation_variant_name = 'he-IL'
  lang.rtl = true
  lang.default_script = hebrew_script
end

l_fr = Language.find_or_create_by!(iso_name: 'fr') do |lang|
  lang.english_name = 'French'
  lang.native_name = 'Français'
  lang.pronunciation_variant_name = 'fr-FR'
  lang.default_script = latin_script
end

l_es = Language.find_or_create_by!(iso_name: 'es') do |lang|
  lang.english_name = 'Spanish'
  lang.native_name = 'Español'
  lang.pronunciation_variant_name = 'es-ES'
  lang.default_script = latin_script
end

l_ar = Language.find_or_create_by!(iso_name: 'ar-JO') do |lang|
  lang.english_name = 'Arabic'
  lang.native_name = 'العربية الفلسطينية'
  lang.pronunciation_variant_name = 'ar-JO'
  lang.rtl = true
  lang.default_script = arabic_script
end

admin = User.new(email: 'ynon@hey.com', password: '10203040', password_confirmation: '10203040')
admin.skip_confirmation!
admin.save!

a_dios_le_pido_data = JSON.parse(File.read(Rails.root.join("test", "fixtures", "courses", "juanes.json")))

mediun = Medium.create!(url: a_dios_le_pido_data["youtubeurl"])
course1 = Course.create!(
  name: "A Dios Le Pido",
  slug: "a-dios-le-pido",
  main_media_url: a_dios_le_pido_data["youtubeurl"],
  language: l_es,
  user: admin,
  status: :published,
)
course1.create_song!(a_dios_le_pido_data)
