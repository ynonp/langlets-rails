#!/usr/bin/env ruby

# Simple script to create a test lesson
require_relative 'config/environment'

# Create languages if they don't exist
english = Language.find_or_create_by!(iso_name: 'en', english_name: 'English', native_name: 'English', pronunciation_variant_name: 'en-US')
hebrew = Language.find_or_create_by!(iso_name: 'he', english_name: 'Hebrew', native_name: 'עברית', pronunciation_variant_name: 'he-IL')

# Create a test medium (YouTube video)
medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ') do |m|
  m.url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
end

# Create a test lesson
lesson = Lesson.find_or_create_by!(slug: 'test-lesson') do |l|
  l.name = 'Test Lesson for Meta Tags'
  l.medium = medium
  l.start_timestamp = '00:00'
  l.end_timestamp = '02:00'
end

# Create some test phrases
phrase1 = Phrase.find_or_create_by!(
  medium: medium,
  l1: english,
  l2: hebrew,
  text_l1: 'Hello world',
  text_l2: 'שלום עולם',
  timestamp: '00:30'
)

phrase2 = Phrase.find_or_create_by!(
  medium: medium,
  l1: english,
  l2: hebrew,
  text_l1: 'How are you?',
  text_l2: 'איך אתה?',
  timestamp: '01:00'
)

puts "Created test lesson with slug: #{lesson.slug}"
puts "You can now test the meta tags at: http://localhost:3000/lessons/#{lesson.slug}" 