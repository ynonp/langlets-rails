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
    # Declared before the guest bail-out: a Course in a public Channel is the
    # one thing the world may read, so this rule must exist for `user == nil`
    # too. Everything else — own Channels, subscribed Channels, admin — is
    # folded into Course#readable_by?, keeping a single definition of "can see
    # this course" shared with the listing queries.
    #
    # A block (rather than hash conditions) because readability is a property
    # of the Channels a Course was published to, not of its own columns. Blocks
    # cannot drive `accessible_by`, which nothing uses — listings go through
    # ChannelContentQuery instead.
    can :read, Course do |course|
      course.readable_by?(user)
    end

    return if user.blank?

    # Every signed-in user owns their playlists: add/remove courses, delete.
    # System playlists (user_id nil) stay admin-only via `editor`.
    can [ :update, :destroy ], Playlist, user_id: user.id
    can :read, Channel, Channel.visible_to(user)
    can :manage, Channel, user_id: user.id
    cannot :create, Channel
    can :create, ChannelInvitation, channel: { user_id: user.id, visibility: Channel.visibilities[:shared] }

    return unless user.admin?

    editor(user)
  end

  def editor(user)
    can :create, Course
    can :manage, Course, user: user
    can :manage, Playlist
    can :manage, Channel
    can :manage, ChannelInvitation
    can :manage, ChannelSubscription
  end
end
