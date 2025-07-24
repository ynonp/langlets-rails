#!/usr/bin/env ruby

# Demonstration script for multi-script phrase functionality
# Run with: ./bin/rails runner script/demo_multi_script.rb

puts "🌍 Multi-Script Phrase Demo"
puts "=" * 50

# Get languages and scripts
hebrew_lang = Language.find_by(iso_name: 'he')
english_lang = Language.find_by(iso_name: 'en')
hebrew_script = Script.find_by(name: 'hebrew')
latin_script = Script.find_by(name: 'latin')

# Create a medium
medium = Medium.create!(url: 'https://example.com/demo-video')

# Create a phrase with traditional fields
phrase = Phrase.create!(
  text_l1: "שלום עולם",
  text_l2: "Hello world",
  l1: hebrew_lang,
  l2: english_lang,
  medium: medium,
  timestamp: "00:01:30"
)

puts "\n📝 Created phrase with traditional fields:"
puts "  L1 (Hebrew): #{phrase.text_l1}"
puts "  L2 (English): #{phrase.text_l2}"

# Now add multi-script variants
puts "\n🔤 Adding multi-script variants..."

# Hebrew text in Hebrew script (primary)
hebrew_text = PhraseText.create!(content: "שלום עולם", script: hebrew_script)
PhraseTextAssignment.create!(
  phrase: phrase,
  phrase_text: hebrew_text,
  language_role: :l1,
  primary: true
)

# Hebrew text in Latin script (transliteration)
latin_hebrew_text = PhraseText.create!(content: "Shalom olam", script: latin_script)
PhraseTextAssignment.create!(
  phrase: phrase,
  phrase_text: latin_hebrew_text,
  language_role: :l1,
  primary: false
)

# English text in Latin script
english_text = PhraseText.create!(content: "Hello world", script: latin_script)
PhraseTextAssignment.create!(
  phrase: phrase,
  phrase_text: english_text,
  language_role: :l2,
  primary: true
)

puts "✅ Multi-script variants added!"

# Demonstrate access methods
puts "\n🔍 Accessing text variants:"
puts "\n  Using new script-specific methods:"
puts "    phrase.text_l1_for_script()                  → #{phrase.text_l1_for_script}"
puts "    phrase.text_l1_for_script(script: 'hebrew')  → #{phrase.text_l1_for_script(script: 'hebrew')}"
puts "    phrase.text_l1_for_script(script: 'latin')   → #{phrase.text_l1_for_script(script: 'latin')}"
puts "    phrase.text_l2_for_script()                  → #{phrase.text_l2_for_script}"

puts "\n  Using traditional methods (backward compatible):"
puts "    phrase.text_l1                               → #{phrase.text_l1}"
puts "    phrase.text_l2                               → #{phrase.text_l2}"

# Show all variants
puts "\n📋 All L1 variants:"
phrase.text_l1_variants.each_with_index do |variant, index|
  puts "    #{index + 1}. #{variant[:script].capitalize} script: #{variant[:text]}"
end

puts "\n📋 All L2 variants:"
phrase.text_l2_variants.each_with_index do |variant, index|
  puts "    #{index + 1}. #{variant[:script].capitalize} script: #{variant[:text]}"
end

# Demonstrate TokenTranslation compatibility
puts "\n🔗 TokenTranslation compatibility:"
token = TokenTranslation.create!(
  phrase: phrase,
  l1_start_index: 0,
  l1_end_index: 0,
  translation: "Hello"
)

puts "    Created TokenTranslation for word index 0"
puts "    token.original_text                          → #{token.original_text}"
puts "    (Uses traditional text_l1 field as expected)"

# Show script information
puts "\n📜 Available scripts in system:"
Script.all.each do |script|
  direction = script.rtl? ? "RTL" : "LTR"
  puts "    #{script.name.capitalize} (#{script.iso_code}) - #{direction}"
end

puts "\n✨ Demo completed! Multi-script support is working correctly."
puts "   Both new script variants and legacy compatibility are maintained."