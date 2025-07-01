# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user

    if ['ynon@hey.com', 'ynonperek@gmail.com'].include?(user.email)
      editor(user)
    end
  end

  def editor(user)
    can :create, Course
    can :manage, Course, user: user
  end
end
