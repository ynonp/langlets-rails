class CourseLearningPathsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_course

  # GET /courses/:course_id/learning_paths
  # Returns every learning path plus whether this course belongs to it.
  # Used to refresh the "add to learning paths" popup.
  def index
    render json: { paths: serialized_paths }
  end

  # POST /courses/:course_id/learning_paths
  # Either attaches an existing path (learning_path_id) or creates a new one (name).
  def create
    path =
      if params[:name].present?
        LearningPath.create!(name: params[:name].strip, published: true, slug: unique_slug(params[:name]))
      else
        LearningPath.find(params[:learning_path_id])
      end

    CoursesLearningPath.find_or_create_by!(course: @course, learning_path: path)

    render json: { path: serialize(path, member: true) }
  end

  # DELETE /courses/:course_id/learning_paths/:id
  def destroy
    path = LearningPath.find(params[:id])
    CoursesLearningPath.where(course: @course, learning_path: path).destroy_all
    render json: { path: serialize(path, member: false) }
  end

  private

  def set_course
    @course = Course.find_by(slug: params[:course_id]) || Course.find(params[:course_id])
    authorize! :manage, @course
  end

  def serialized_paths
    member_ids = @course.learning_path_ids.to_set
    LearningPath.order(created_at: :desc).map do |path|
      serialize(path, member: member_ids.include?(path.id))
    end
  end

  def serialize(path, member:)
    {
      id: path.id,
      name: path.name.to_s,
      courses_count: path.courses.count,
      member: member
    }
  end

  def unique_slug(name)
    base = name.parameterize.presence || "learning-path"
    slug = base
    counter = 1
    while LearningPath.exists?(slug: slug)
      slug = "#{base}-#{counter}"
      counter += 1
    end
    slug
  end
end
