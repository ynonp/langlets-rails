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
latin_script = Script.find_or_create_by!(code: 'latn') do |script|
  script.name = 'Latin'
end

hebrew_script = Script.find_or_create_by!(code: 'hebr') do |script|
  script.name = 'Hebrew'
end

arabic_script = Script.find_or_create_by!(code: 'arab') do |script|
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

admin = User.find_or_create_by(email: 'ynon@hey.com') do |user|
  user.password = '10203040'
  user.password_confirmation = '10203040'
  user.skip_confirmation!
end

a_dios_le_pido_data = JSON.parse(File.read(Rails.root.join("test", "fixtures", "courses", "juanes.json")))

mediun = Medium.find_or_create_by(url: a_dios_le_pido_data["youtubeurl"])
course1 = Course.create!(
  slug: "a-dios-le-pido",
  name: "A Dios Le Pido",
  main_media_url: a_dios_le_pido_data["youtubeurl"],
  language: l_es,
  user: admin,
  status: :published,
  hebrew_script_available: true
)
course1.create_song!(a_dios_le_pido_data)

haifa_jenin_data = JSON.parse(File.read(Rails.root.join("test", "fixtures", "courses", "haifa-jenin.json")))
course2 = Course.create!(
  slug: 'haifa-jenin',
  name: 'حيفا جنين',
  main_media_url: haifa_jenin_data["youtubeurl"],
  language: l_ar,
  user: admin,
  status: :published,
  hebrew_script_available: true
)
course2.create_song!(haifa_jenin_data)