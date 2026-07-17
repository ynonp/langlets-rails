# A course on the user's Home. Created when they import a video (source:
# :imported) or tap "+ Learn this" in the Library (source: :library) — the latter
# happens before any lesson is completed, which is why enrollment can't be
# inferred from lesson_users.
class Enrollment < ApplicationRecord
  belongs_to :user
  belongs_to :course

  enum :source, { imported: 0, library: 1, learning_path: 2 }

  validates :course_id, uniqueness: { scope: :user_id }

  # Home's "Keep it going" order. NULLS LAST so a course that was added but never
  # opened sorts below one the user is actually working through.
  scope :recently_practiced, -> { order(Arel.sql("last_practiced_at DESC NULLS LAST")) }
  scope :in_progress, -> { where.not(last_practiced_at: nil) }

  def touch_practised!
    update_column(:last_practiced_at, Time.zone.now)
  end
end
