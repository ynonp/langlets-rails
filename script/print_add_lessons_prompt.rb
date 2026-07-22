#!/usr/bin/env ruby

require "json"
require "open3"

progress_id = ARGV.first
abort "Usage: bin/rails runner script/print_add_lessons_prompt.rb CREATE_SONG_PROGRESS_ID" if progress_id.blank?

ActiveRecord::Base.logger = nil
progress = CreateSongProgress.find(progress_id)
clip_language = progress.clip_language
translation_language = progress.translation_language.presence || "English"

deno_source = <<~JAVASCRIPT
  import { addLessonsPrompt } from "./src/prompts/addLessons.ts";
  console.log(addLessonsPrompt(#{clip_language.to_json}, #{translation_language.to_json}));
JAVASCRIPT

system_prompt, error_output, status = Open3.capture3(
  "deno",
  "eval",
  deno_source,
  chdir: Rails.root.join("pipeline").to_s
)
abort "Could not render add-lessons prompt:\n#{error_output}" unless status.success?

words = Array(progress.data&.dig("phrases")).flat_map do |phrase|
  Array(phrase["words"]).filter_map { |word| word["text"].presence }
end
abort "CreateSongProgress #{progress.id} has no aligned words" if words.empty?

puts "=== SYSTEM MESSAGE ==="
puts system_prompt.chomp
puts
puts "=== USER MESSAGE ==="
puts words.join(" ")
