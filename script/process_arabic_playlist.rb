#!/usr/bin/env ruby

require 'json'
require_relative '../config/environment'

# Load the playlist data
playlist_file = File.join(Rails.root, 'playlist.json')
playlist_data = JSON.parse(File.read(playlist_file))

puts "Processing Arabic playlist: #{playlist_data['title']}"
puts "Total videos: #{playlist_data['entries'].length}"
puts "=" * 60

# Process each video in the playlist
playlist_data['entries'].each_with_index do |entry, index|
  # Skip deleted videos
  if entry['title'] == '[Deleted video]' || entry['title'].nil?
    puts "#{index + 1}. Skipping deleted video: #{entry['id']}"
    next
  end

  video_id = entry['id']
  video_url = entry['url']
  video_title = entry['title']

  puts "#{index + 1}. Processing: #{video_title}"
  puts "   Video ID: #{video_id}"
  puts "   URL: #{video_url}"

  begin
    # Create and run the AI song processor
    puts "   Creating AI song processor..."
    cs = Ai::CreateSong.new(video_id, video_url, 'Arabic', 'English')
    
    puts "   Running AI processing..."
    cs.run
    
    # Create the course
    puts "   Creating course..."
    c = Course.create!(
      name: video_title, 
      slug: video_id, 
      main_media_url: video_url
    )
    
    # Find the progress and create the song
    puts "   Finding progress and creating song..."
    progress = CreateSongProgress.find_by(
      youtubeurl: video_url, 
      clip_language: "Arabic", 
      translation_language: "English"
    )
    
    if progress
      c.create_song!(progress)
      puts "   ✅ Successfully processed video #{video_id}"
    else
      puts "   ⚠️  Warning: No progress found for video #{video_id}"
    end
    
  rescue => e
    puts "   ❌ Error processing video #{video_id}: #{e.message}"
    puts "   #{e.backtrace.first}"
    # Continue with the next video instead of failing completely
    next
  end
  
  puts "   " + "-" * 50
  
  # Add a small delay between videos to avoid overwhelming the system
  sleep 2
end

puts "=" * 60
puts "Playlist processing completed!"
