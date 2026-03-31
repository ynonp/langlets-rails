namespace :create_song_progress do
  desc "Export a CreateSongProgress record to JSON file"
  task :export, [ :youtubeurl, :clip_language, :translation_language, :output_file ] => :environment do |t, args|
    if args[:youtubeurl].blank? || args[:clip_language].blank? || args[:translation_language].blank?
      puts "Usage: rake create_song_progress:export[youtubeurl,clip_language,translation_language,output_file]"
      puts "Example: rake create_song_progress:export['https://youtube.com/watch?v=abc123','Spanish','English','progress.json']"
      exit 1
    end

    progress = CreateSongProgress.find_by(
      youtubeurl: args[:youtubeurl],
      clip_language: args[:clip_language],
      translation_language: args[:translation_language]
    )

    if progress.nil?
      puts "CreateSongProgress not found for:"
      puts "  YouTube URL: #{args[:youtubeurl]}"
      puts "  Clip Language: #{args[:clip_language]}"
      puts "  Translation Language: #{args[:translation_language]}"
      exit 1
    end

    output_file = args[:output_file] || "create_song_progress_#{Time.current.to_i}.json"

    export_data = {
      youtubeurl: progress.youtubeurl,
      clip_language: progress.clip_language,
      translation_language: progress.translation_language,
      step: progress.step,
      data: progress.data,
      created_at: progress.created_at,
      updated_at: progress.updated_at,
      exported_at: Time.current.iso8601
    }

    File.write(output_file, JSON.pretty_generate(export_data))

    puts "CreateSongProgress exported successfully to: #{output_file}"
    puts "Step: #{progress.step}"
    puts "Created: #{progress.created_at}"
    puts "Updated: #{progress.updated_at}"
  end

  desc "Import a CreateSongProgress record from JSON file"
  task :import, [ :input_file, :overwrite ] => :environment do |t, args|
    if args[:input_file].blank?
      puts "Usage: rake create_song_progress:import[input_file,overwrite]"
      puts "Example: rake create_song_progress:import['progress.json',true]"
      puts "  overwrite: true/false (default: false) - whether to overwrite existing records"
      exit 1
    end

    unless File.exist?(args[:input_file])
      puts "File not found: #{args[:input_file]}"
      exit 1
    end

    begin
      import_data = JSON.parse(File.read(args[:input_file]))
    rescue JSON::ParserError => e
      puts "Invalid JSON file: #{e.message}"
      exit 1
    end

    required_fields = %w[youtubeurl clip_language translation_language step]
    missing_fields = required_fields - import_data.keys

    if missing_fields.any?
      puts "Missing required fields in JSON: #{missing_fields.join(', ')}"
      exit 1
    end

    overwrite = args[:overwrite]&.downcase == "true"

    existing_progress = CreateSongProgress.find_by(
      youtubeurl: import_data["youtubeurl"],
      clip_language: import_data["clip_language"],
      translation_language: import_data["translation_language"]
    )

    if existing_progress && !overwrite
      puts "CreateSongProgress already exists for:"
      puts "  YouTube URL: #{import_data['youtubeurl']}"
      puts "  Clip Language: #{import_data['clip_language']}"
      puts "  Translation Language: #{import_data['translation_language']}"
      puts "Use overwrite=true to replace existing record"
      exit 1
    end

    progress = existing_progress || CreateSongProgress.new

    progress.assign_attributes(
      youtubeurl: import_data["youtubeurl"],
      clip_language: import_data["clip_language"],
      translation_language: import_data["translation_language"],
      step: import_data["step"],
      data: import_data["data"]
    )

    if progress.save
      action = existing_progress ? "updated" : "created"
      puts "CreateSongProgress #{action} successfully!"
      puts "  YouTube URL: #{progress.youtubeurl}"
      puts "  Clip Language: #{progress.clip_language}"
      puts "  Translation Language: #{progress.translation_language}"
      puts "  Step: #{progress.step}"
      puts "  Data keys: #{progress.data&.keys&.join(', ') || 'none'}"

      if import_data["exported_at"]
        puts "  Originally exported: #{import_data['exported_at']}"
      end
    else
      puts "Failed to save CreateSongProgress:"
      puts progress.errors.full_messages.join("\n")
      exit 1
    end
  end

  desc "Process YouTube URLs from file and save to fixtures"
  task :process_urls, [ :input_file, :clip_language, :translation_language ] => :environment do |t, args|
    if args[:input_file].blank?
      puts "Usage: rake create_song_progress:process_urls[input_file,clip_language,translation_language]"
      puts "Example: rake create_song_progress:process_urls['urls.txt','Hebrew','English']"
      exit 1
    end

    unless File.exist?(args[:input_file])
      puts "File not found: #{args[:input_file]}"
      exit 1
    end

    clip_language = args[:clip_language] || "Hebrew"
    translation_language = args[:translation_language] || "English"

    output_dir = Rails.root.join("test", "fixtures", "create_song_progress")
    FileUtils.mkdir_p(output_dir)

    urls = File.readlines(args[:input_file]).map(&:strip).reject(&:blank?)

    if urls.empty?
      puts "No URLs found in file: #{args[:input_file]}"
      exit 1
    end

    puts "Processing #{urls.count} URL(s)..."
    puts "Clip Language: #{clip_language}"
    puts "Translation Language: #{translation_language}"
    puts

    urls.each_with_index do |url, index|
      puts "[#{index + 1}/#{urls.count}] Processing: #{url}"

      progress = CreateSongProgress.find_or_initialize_by(
        youtubeurl: url,
        clip_language: clip_language,
        translation_language: translation_language
      )

      progress.data ||= {}
      progress.use_local_ollama

      begin
        progress.create_data

        video_id = url.gsub(/[^a-zA-Z0-9]/, "_")
        output_file = output_dir.join("#{video_id}.json")

        progress.export(output_file)

        puts "  Saved to: #{output_file}"
        puts "  Step: #{progress.step}"
        puts "  Data keys: #{progress.data&.keys&.join(', ') || 'none'}"
      rescue => e
        puts "  ERROR: #{e.message}"
        puts "  #{e.backtrace.first(5).join("\n  ")}"
      end

      puts
    end

    puts "Done! Files saved to: #{output_dir}"
  end

  desc "List all CreateSongProgress records"
  task list: :environment do
    progresses = CreateSongProgress.all

    if progresses.empty?
      puts "No CreateSongProgress records found."
      exit 0
    end

    puts "Found #{progresses.count} CreateSongProgress record(s):"
    puts

    progresses.each do |progress|
      puts "YouTube URL: #{progress.youtubeurl}"
      puts "Clip Language: #{progress.clip_language}"
      puts "Translation Language: #{progress.translation_language}"
      puts "Step: #{progress.step}"
      puts "Created: #{progress.created_at}"
      puts "Updated: #{progress.updated_at}"
      puts "Data keys: #{progress.data&.keys&.join(', ') || 'none'}"
      puts "-" * 50
    end
  end
end
