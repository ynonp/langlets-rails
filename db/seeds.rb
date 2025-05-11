# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

Language.create!(iso_name: 'en', english_name: 'English', native_name: 'English', pronunciation_variant_name: 'en-US')
Language.create!(iso_name: 'he', english_name: 'Hebrew', native_name: 'עברית', pronunciation_variant_name: 'he-IL')
Language.create!(iso_name: 'fr', english_name: 'French', native_name: 'Français', pronunciation_variant_name: 'fr-FR')
Language.create!(iso_name: 'es', english_name: 'Spanish', native_name: 'Español', pronunciation_variant_name: 'es-ES')
Language.create!(iso_name: 'ar-ps', english_name: 'Palestinian Arabic', native_name: 'العربية الفلسطينية', pronunciation_variant_name: 'ar-JO')

