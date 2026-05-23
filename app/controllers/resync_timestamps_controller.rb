class ResyncTimestampsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_resync

  def new
  end

  def create
    course_slug = params[:course_slug]&.strip
    file = params[:file]

    if course_slug.blank?
      redirect_to new_resync_timestamp_path, alert: "Please enter a course slug."
      return
    end

    if file.nil? || file.blank?
      redirect_to new_resync_timestamp_path, alert: "Please upload a JSON or SRT file."
      return
    end

    course = Course.find_by(slug: course_slug)
    if course.nil?
      redirect_to new_resync_timestamp_path, alert: "Course with slug '#{course_slug}' not found."
      return
    end

    medium = course.medium
    if medium.nil?
      redirect_to new_resync_timestamp_path, alert: "Course has no associated medium."
      return
    end

    original_filename = file.respond_to?(:original_filename) ? file.original_filename : nil

    file_content = if file.respond_to?(:read)
                     file.read
    elsif file.is_a?(String)
                     file
    elsif file.respond_to?(:tempfile) && file.tempfile
                     file.tempfile.read
    else
                     redirect_to new_resync_timestamp_path, alert: "Unknown file format."
                     return
    end

    is_srt = original_filename&.end_with?(".srt") || file_content.strip.match?(/^\d+\s*\n\d{2}:\d{2}:\d{2},\d{3}\s*-->/)

    if is_srt
      begin
        json_data = parse_srt_to_json_array(file_content)
      rescue => e
        redirect_to new_resync_timestamp_path, alert: "Invalid SRT file: #{e.message}"
        return
      end
    else
      begin
        json_data = JSON.parse(file_content)
      rescue JSON::ParserError => e
        redirect_to new_resync_timestamp_path, alert: "Invalid JSON: #{e.message}"
        return
      end
    end

    unless json_data.is_a?(Array)
      redirect_to new_resync_timestamp_path, alert: "JSON must be an array of objects."
      return
    end

    phrase_count = medium.phrases.count
    if json_data.length != phrase_count
      redirect_to new_resync_timestamp_path, alert: "JSON has #{json_data.length} entries but course medium has #{phrase_count} phrases."
      return
    end

    ResyncTimestampsJob.perform_later(course.id, json_data)

    redirect_to courses_path, notice: "Timestamp resync job started for '#{course.name}'. It will run in the background."
  end

  private

  def parse_srt_to_json_array(srt_content)
    blocks = srt_content.strip.split(/\n\s*\n/)
    blocks.map do |block|
      lines = block.strip.split("\n")
      next if lines.length < 2

      # Second line contains the timestamp range: "HH:MM:SS,mmm --> HH:MM:SS,mmm"
      timestamp_line = lines[1]
      match = timestamp_line.match(/^(\d{2}:\d{2}:\d{2},\d{3})\s*-->/)
      next unless match

      { "timestamp" => match[1].sub(",", ".") }
    end.compact
  end

  def authorize_resync
    authorize! :create, Course
  end
end
