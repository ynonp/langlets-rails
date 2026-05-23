# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create languages (no longer need scripts or default_script references)
l_en = Language.find_or_create_by!(iso_name: 'en') do |lang|
  lang.english_name = 'English'
  lang.native_name = 'English'
  lang.pronunciation_variant_name = 'en-US'
end

l_he = Language.find_or_create_by!(iso_name: 'he') do |lang|
  lang.english_name = 'Hebrew'
  lang.native_name = 'עברית'
  lang.pronunciation_variant_name = 'he-IL'
  lang.rtl = true
end

l_fr = Language.find_or_create_by!(iso_name: 'fr') do |lang|
  lang.english_name = 'French'
  lang.native_name = 'Français'
  lang.pronunciation_variant_name = 'fr-FR'
end

l_es = Language.find_or_create_by!(iso_name: 'es') do |lang|
  lang.english_name = 'Spanish'
  lang.native_name = 'Español'
  lang.pronunciation_variant_name = 'es-ES'
end

l_de = Language.find_or_create_by!(iso_name: 'de') do |lang|
  lang.english_name = 'German'
  lang.native_name = 'Deutsch'
  lang.pronunciation_variant_name = 'de-DE'
end

l_ar = Language.find_or_create_by!(iso_name: 'ar-JO') do |lang|
  lang.english_name = 'Arabic'
  lang.native_name = 'العربية الفلسطينية'
  lang.pronunciation_variant_name = 'ar-JO'
  lang.rtl = true
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
  status: :published
)
course1.create_song!(a_dios_le_pido_data)

haifa_jenin_data = JSON.parse(File.read(Rails.root.join("test", "fixtures", "courses", "haifa-jenin.json")))
course2 = Course.create!(
  slug: 'haifa-jenin',
  name: 'حيفا جنين',
  main_media_url: haifa_jenin_data["youtubeurl"],
  language: l_ar,
  user: admin,
  status: :published
)
course2.create_song!(haifa_jenin_data)