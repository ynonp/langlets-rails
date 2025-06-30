# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    if ['ynon@hey.com'].include?(user)
      editor(user)
    end
  end

  def editor(user)
    can :create, Course
    can :manage, Course, user: user
  end
end
