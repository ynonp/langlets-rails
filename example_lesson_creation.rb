# Example usage of the CreateSong class for lesson creation

# Initialize the CreateSong instance
song_creator = Ai::CreateSong.new(
  "Despacito", 
  "https://youtube.com/watch?v=example", 
  "Spanish", 
  "English"
)

# Step 1: Extract phrases from the song
puts "Creating phrases..."
song_creator.create_phrases

# Step 2: Create lessons from the phrases
puts "Creating lessons..."
lessons = song_creator.create_lessons

# The lessons now contain full phrase information for validation
if lessons
  puts "Lesson creation complete!"
  puts "Created #{lessons.length} lessons:"
  
  lessons.each_with_index do |lesson, index|
    puts "\nLesson #{index + 1}: #{lesson.title}"
    puts "  Description: #{lesson.description}"
    puts "  Time: #{lesson.start_timestamp} - #{lesson.end_timestamp} (calculated)"
    puts "  Phrases (#{lesson.phrases.length}):"
    lesson.phrases.each do |phrase|
      puts "    [#{phrase['index']}] #{phrase['text_l1']} -> #{phrase['text_l2']} (#{phrase['timestamp']})"
    end
  end
end

# Step 3: (Optional) Create actual Lesson model instances
# Assuming you have a Medium instance for the song
# medium = Medium.find_by(url: "https://youtube.com/watch?v=example")
# actual_lessons = song_creator.create_lesson_models(medium)
