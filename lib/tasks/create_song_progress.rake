namespace :create_song_progress do
  desc "Run the Deno pipeline, create the course, and wait (youtube_url, clip_language, translation_language, creator_email)"
  task :pipeline, [ :youtube_url, :clip_language, :translation_language, :creator_email ] => :environment do |_task, args|
    if args.values_at(:youtube_url, :clip_language, :translation_language).any?(&:blank?)
      abort <<~USAGE
        Usage: rake "create_song_progress:pipeline[youtube_url,clip_language,translation_language,creator_email]"
        Example: rake "create_song_progress:pipeline[https://www.youtube.com/watch?v=XXXX,French,Hebrew,ynon@hey.com]"

        Start Rails separately with the same PIPELINE_HMAC_SECRET. The callback base URL
        defaults to http://localhost:3000 and can be changed with PIPELINE_CALLBACK_BASE_URL.
        creator_email defaults to COURSE_CREATOR_EMAIL, then ynon@hey.com.
      USAGE
    end

    progress = CreateSongPipelineCli.new(
      youtube_url: args[:youtube_url],
      clip_language: args[:clip_language],
      translation_language: args[:translation_language],
      callback_base_url: ENV["PIPELINE_CALLBACK_BASE_URL"]
    ).call

    puts "Deno pipeline finished successfully for CreateSongProgress #{progress.id}."

    creator_email = args[:creator_email].presence || ENV["COURSE_CREATOR_EMAIL"].presence || "ynon@hey.com"
    creator = User.find_by(email: creator_email)
    raise ArgumentError, "unknown course creator: #{creator_email}" unless creator

    ImportCourseJob.perform_now(progress.id, creator.id)
    puts "Course created successfully for CreateSongProgress #{progress.id}."
  rescue ArgumentError => e
    abort e.message
  end

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

    unless CreateSongProgress::DataFormat.current?(import_data["data"])
      puts "This file uses the legacy single-language data format."
      puts "Convert it first: rake \"create_song_progress:convert_files[#{args[:input_file]}]\""
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

  desc "Seed extract_lyrics from a word-timing JSON file and run the rest of the pipeline"
  task :build_from_word_timing, [ :json_file, :youtubeurl, :clip_language, :translation_language, :output_file ] => :environment do |t, args|
    if args[:json_file].blank? || args[:youtubeurl].blank? || args[:clip_language].blank? || args[:translation_language].blank?
      puts "Usage: rake create_song_progress:build_from_word_timing[json_file,youtubeurl,clip_language,translation_language,output_file]"
      puts "Example: rake \"create_song_progress:build_from_word_timing[apt_word_timing.json,https://www.youtube.com/watch?v=ekr2nIex040,English,Hebrew,/tmp/apt_word_timed_progress.json]\""
      exit 1
    end

    unless File.exist?(args[:json_file])
      puts "File not found: #{args[:json_file]}"
      exit 1
    end

    # Seed the extract_lyrics result straight from the word-timing JSON (same
    # parser the live extract step uses), so we skip the YouTube transcription
    # call and run only the steps that come after it.
    phrases = WordTimingParser.parse(File.read(args[:json_file]))
    puts "Parsed #{phrases.length} phrases (#{phrases.sum { |p| p["words"].length }} words) from #{args[:json_file]}"

    progress = CreateSongProgress.find_or_initialize_by(
      youtubeurl: args[:youtubeurl],
      clip_language: args[:clip_language],
      translation_language: args[:translation_language]
    )
    progress.data = { "phrases" => phrases }
    progress.save!

    puts "1/3 add_lessons..."
    progress.add_lessons
    puts "2/3 add_similar_sound..."
    progress.add_similar_sound
    puts "3/3 add_translation (line-level L2 + per-word translations)..."
    progress.add_translation(args[:translation_language])

    output_file = args[:output_file] || "word_timed_progress_#{Time.current.to_i}.json"
    progress.export(output_file)

    puts "Done! Exported to: #{output_file}"
    puts "Import with: rake \"create_song_progress:import[#{output_file},true]\""
  end

  desc "Convert legacy-format CreateSongProgress JSON files (exports and fixtures) to the multi-language format"
  task :convert_files, [ :glob ] => :environment do |t, args|
    pattern = args[:glob].presence || Rails.root.join("test/fixtures/create_song_progress/**/*.json").to_s
    files = Dir.glob(pattern).sort

    if files.empty?
      puts "No files match #{pattern}"
      exit 1
    end

    converted = skipped = failed = 0

    files.each do |path|
      json = JSON.parse(File.read(path))

      if CreateSongProgress::DataFormat.current?(json["data"])
        skipped += 1
        next
      end

      language = Language.find_by(english_name: json["translation_language"])
      if language.nil?
        puts "FAILED #{path}: unknown translation language #{json['translation_language'].inspect}"
        failed += 1
        next
      end

      CreateSongProgress::DataFormat.pack_translation(json["data"], language)
      File.write(path, JSON.pretty_generate(json))
      puts "converted #{path}"
      converted += 1
    rescue JSON::ParserError => e
      puts "FAILED #{path}: invalid JSON (#{e.message})"
      failed += 1
    end

    puts
    puts "#{converted} converted, #{skipped} already current, #{failed} failed"
    exit 1 if failed > 0
  end

  desc "Convert legacy-format CreateSongProgress DB records to the multi-language format"
  task convert_records: :environment do
    converted = skipped = failed = 0

    CreateSongProgress.find_each do |progress|
      if progress.current_data_format?
        skipped += 1
        next
      end

      progress.upgrade_data_format!
      puts "converted #{progress.id} #{progress.youtubeurl} (#{progress.clip_language} / #{progress.translation_language})"
      converted += 1
    rescue => e
      puts "FAILED #{progress.id} #{progress.youtubeurl}: #{e.message}"
      failed += 1
    end

    puts
    puts "#{converted} converted, #{skipped} already current, #{failed} failed"
    exit 1 if failed > 0
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
