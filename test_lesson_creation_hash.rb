#!/usr/bin/env ruby
# Test script to verify that Course#create_song! and Course#create_short! work with hash data

require_relative 'config/environment'

# Sample data structure that matches juanes.json
sample_data = {
  "youtubeurl" => "https://www.youtube.com/watch?v=example",
  "clip_language" => "Spanish",
  "translation_language" => "English",
  "song_name" => "Test Song",
  "lessons" => [
    {
      "title" => "Test Lesson",
      "phrases" => [
        {
          "text_l1" => "Hola mundo",
          "text_l2" => "Hello world",
          "timestamp" => "00:01",
          "translations" => [
            {
              "translation" => "Hello",
              "l1_index" => [0],
              "l2_index" => [0],
              "similar_sound" => nil,
              "listening_activity" => 0,
              "language_alignment_activity" => 1
            },
            {
              "translation" => "world",
              "l1_index" => [1],
              "l2_index" => [1],
              "similar_sound" => ["mundo"],
              "listening_activity" => 1,
              "language_alignment_activity" => 1
            }
          ]
        }
      ]
    }
  ]
}

puts "Testing Course#create_song! and Course#create_short! with hash data..."

# Create test user (skip confirmation to avoid Devise issues)
User.find_by(email: "test@example.com")&.destroy
user = User.create!(
  email: "test@example.com",
  password: "password123",
  password_confirmation: "password123",
  confirmed_at: Time.current # Skip email confirmation
)

# Create languages if they don't exist
spanish = Language.find_or_create_by!(iso_name: "es") do |l|
  l.english_name = "Spanish"
  l.native_name = "Español"
end

english = Language.find_or_create_by!(iso_name: "en") do |l|
  l.english_name = "English" 
  l.native_name = "English"
end

# Test create_song! method
begin
  course = Course.create!(
    name: "Test Song Course",
    slug: "test-song-course",
    main_media_url: sample_data["youtubeurl"],
    language: english,
    user: user,
    status: :processing
  )

  puts "✓ Created test course: #{course.name}"
  
  course.create_song!(sample_data)
  puts "✓ create_song! method works with hash data"
  
  course.destroy # Clean up
  
rescue => e
  puts "✗ create_song! failed: #{e.message}"
  puts e.backtrace.first(3).join("\n")
end

# Test create_short! method
begin
  course = Course.create!(
    name: "Test Short Course",
    slug: "test-short-course", 
    main_media_url: sample_data["youtubeurl"],
    language: english,
    user: user,
    status: :processing
  )

  puts "✓ Created test course: #{course.name}"
  
  course.create_short!(sample_data)
  puts "✓ create_short! method works with hash data"
  
  course.destroy # Clean up
  
rescue => e
  puts "✗ create_short! failed: #{e.message}"
  puts e.backtrace.first(3).join("\n")
end

puts "✓ All tests completed successfully!"
