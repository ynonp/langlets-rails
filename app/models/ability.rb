# frozen_string_literal: true

class Ability
  include CanCan::Ability

  # Deliberately still admin-only, including for `:create, Course`.
  #
  # It's tempting to open `:create, Course` now that any user can import a video,
  # but that permission is shared by three admin surfaces — the hand-typed course
  # form (courses#new/#create), the arbitrary-JSON importer
  # (import_courses#new/#create) and resync_timestamps#create — and it renders the
  # matching links on the web home. Opening it would let any signed-in user create
  # unlimited courses through /courses/new for free, bypassing credits entirely.
  #
  # The mobile import path does not use CanCan at all: it authorizes on
  # authenticate_user! plus a credit balance, creates an ImportRequest, and lets
  # CreateCourseJob build the Course server-side.
  def initialize(user)
    return if user.blank?
    return unless user.admin?

    editor(user)
  end

  def editor(user)
    can :create, Course
    can :manage, Course, user: user
    can :manage, LearningPath
  end
end
