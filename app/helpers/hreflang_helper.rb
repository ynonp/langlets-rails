module HreflangHelper
  def hreflang_tags_for_course(course)
    return "" unless course.language&.iso_name

    tags = []
    tags << tag.link(rel: "alternate", hreflang: course.language.iso_name.downcase,
                     href: canonical_url(course_path(course)))
    tags << tag.link(rel: "alternate", hreflang: "x-default",
                     href: canonical_url(root_path))
    safe_join(tags, "\n    ")
  end
end
