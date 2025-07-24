# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

Language.find_or_create_by!(iso_name: 'en') do |lang|
  lang.english_name = 'English'
  lang.native_name = 'English'
  lang.pronunciation_variant_name = 'en-US'
end

Language.find_or_create_by!(iso_name: 'he') do |lang|
  lang.english_name = 'Hebrew'
  lang.native_name = 'עברית'
  lang.pronunciation_variant_name = 'he-IL'
  lang.rtl = true
end

Language.find_or_create_by!(iso_name: 'fr') do |lang|
  lang.english_name = 'French'
  lang.native_name = 'Français'
  lang.pronunciation_variant_name = 'fr-FR'
end

Language.find_or_create_by!(iso_name: 'es') do |lang|
  lang.english_name = 'Spanish'
  lang.native_name = 'Español'
  lang.pronunciation_variant_name = 'es-ES'
end

Language.find_or_create_by!(iso_name: 'ar-JO') do |lang|
  lang.english_name = 'Arabic'
  lang.native_name = 'العربية الفلسطينية'
  lang.pronunciation_variant_name = 'ar-JO'
  lang.rtl = true
end

# Create scripts for different writing systems
Script.find_or_create_by!(name: 'latin') do |script|
  script.iso_code = 'Latn'
  script.rtl = false
end

Script.find_or_create_by!(name: 'hebrew') do |script|
  script.iso_code = 'Hebr'
  script.rtl = true
end

Script.find_or_create_by!(name: 'arabic') do |script|
  script.iso_code = 'Arab'
  script.rtl = true
end

Script.find_or_create_by!(name: 'cyrillic') do |script|
  script.iso_code = 'Cyrl'
  script.rtl = false
end

admin = User.find_or_initialize_by(email: 'ynon@hey.com')
admin.password = '10203040'
admin.password_confirmation = '10203040'
admin.skip_confirmation!
admin.save!
