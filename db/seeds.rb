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

l_el = Language.find_or_create_by!(iso_name: 'el') do |lang|
  lang.english_name = 'Greek'
  lang.native_name = 'Ελληνικά'
  lang.pronunciation_variant_name = 'el-GR'
end

l_sv = Language.find_or_create_by!(iso_name: 'sv') do |lang|
  lang.english_name = 'Swedish'
  lang.native_name = 'Svenska'
  lang.pronunciation_variant_name = 'sv-SE'
end

admin = User.find_or_create_by(email: 'ynon@hey.com') do |user|
  user.password = '10203040'
  user.password_confirmation = '10203040'
  user.skip_confirmation!
end
