class ImportCoursesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_import

  def new
  end

  def create
    files = Array(params[:files]).compact

    if files.empty?
      redirect_to new_import_course_path, alert: "Please select at least one JSON file to import."
      return
    end

    successful_imports = []
    errors = []

    files.each do |file|
      next unless file.present?

      result = process_file(file)

      if result[:success]
        successful_imports << result
      else
        errors << result[:error]
      end
    end

    if successful_imports.any?
      learning_path_id = nil

      if params[:create_learning_path] == "1"
        name = params[:learning_path_name]&.strip

        if name.blank?
          redirect_to new_import_course_path, alert: "Learning path name is required when creating a learning path.", files: successful_imports
          return
        end

        learning_path = create_learning_path
        if learning_path
          learning_path_id = learning_path.id
        end
      end

      successful_imports.each do |import_data|
        ImportCourseJob.perform_later(import_data[:progress_id], current_user.id, learning_path_id)
      end

      flash[:notice] = "#{successful_imports.count} course(s) are being imported. You'll receive an email when each one is ready."
      flash[:notice] += " Courses will be added to the learning path '#{learning_path.name}'." if learning_path
      redirect_to courses_path
    else
      redirect_to new_import_course_path, alert: "Failed to import courses: #{errors.join(', ')}"
    end
  end

  private

  def authorize_import
    authorize! :create, Course
  end

  def create_learning_path
    name = params[:learning_path_name]&.strip
    description = params[:learning_path_description]&.strip
    difficulty_level = params[:difficulty_level]&.to_i

    return nil if name.blank?

    LearningPath.create!(
      name: name,
      description: description,
      difficulty_level: difficulty_level.presence,
      published: true
    )
  rescue => e
    Rails.logger.error "Failed to create learning path: #{e.message}"
    nil
  end

  def process_file(file)
    file_content = if file.respond_to?(:read)
                      file.read
    elsif file.is_a?(String)
                      file
    elsif file.respond_to?(:tempfile) && file.tempfile
                      file.tempfile.read
    else
                      return { success: false, error: "Unknown file format" }
    end

    begin
      json_data = JSON.parse(file_content)
    rescue JSON::ParserError => e
      filename = file.respond_to?(:original_filename) ? file.original_filename : "unknown"
      return { success: false, error: "Invalid JSON in #{filename}: #{e.message}" }
    end

    required_fields = %w[youtubeurl clip_language translation_language data]
    missing_fields = required_fields - json_data.keys

    if missing_fields.any?
      filename = file.respond_to?(:original_filename) ? file.original_filename : "unknown"
      return {
        success: false,
        error: "Missing required fields in #{filename}: #{missing_fields.join(', ')}"
      }
    end

    unless json_data["data"].is_a?(Hash) && json_data["data"]["lessons"].present?
      filename = file.respond_to?(:original_filename) ? file.original_filename : "unknown"
      return {
        success: false,
        error: "Invalid data structure in #{filename}: 'data' must contain 'lessons'"
      }
    end

    clip_language = json_data["clip_language"]
    translation_language = json_data["translation_language"]

    unless Language.exists?(english_name: clip_language)
      filename = file.respond_to?(:original_filename) ? file.original_filename : "unknown"
      return {
        success: false,
        error: "Unknown clip language '#{clip_language}' in #{filename}"
      }
    end

    progress = CreateSongProgress.find_or_initialize_by(
      youtubeurl: json_data["youtubeurl"],
      clip_language: clip_language,
      translation_language: translation_language
    )

    progress.assign_attributes(
      step: json_data["step"] || 5,
      data: json_data["data"]
    )

    if progress.save
      { success: true, progress_id: progress.id }
    else
      filename = file.respond_to?(:original_filename) ? file.original_filename : "unknown"
      {
        success: false,
        error: "Failed to save progress for #{filename}: #{progress.errors.full_messages.join(', ')}"
      }
    end
  end
end
