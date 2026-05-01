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
      redirect_to new_resync_timestamp_path, alert: "Please upload a JSON file."
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

    begin
      json_data = JSON.parse(file_content)
    rescue JSON::ParserError => e
      redirect_to new_resync_timestamp_path, alert: "Invalid JSON: #{e.message}"
      return
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

  def authorize_resync
    authorize! :create, Course
  end
end
