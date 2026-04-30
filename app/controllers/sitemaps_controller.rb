class SitemapsController < ApplicationController
  def show
    @courses = Course.published_courses.includes(:language).order(updated_at: :desc)
    @learning_paths = LearningPath.published.order(updated_at: :desc)
    @static_pages = [
      { path: root_path, priority: 1.0, changefreq: "daily" },
      { path: home_privacy_path, priority: 0.3, changefreq: "monthly" },
      { path: home_terms_path, priority: 0.3, changefreq: "monthly" }
    ]

    respond_to do |format|
      format.xml { render layout: false }
    end
  end
end
