# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user
    editor(user)
  end

  def editor(user)
    can :create, Course
    can :manage, Course, user: user
  end
end
