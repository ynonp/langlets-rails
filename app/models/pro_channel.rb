# A Langlets Pro subscriber's library.
#
# The subscriber owns it, and everything they import while subscribed is
# published here rather than to their default Channel. What makes it different
# from any other private Channel is that reading it is **lent, not owned**: it
# goes dark the moment the subscription lapses and comes back whole when it
# resumes. Nothing is moved or deleted either way — the ChannelItems sit exactly
# where they were, which is what makes reactivation instant.
#
# The entitlement lives in exactly one place, `User#pro?`, which is derived from
# the Apple subscription's expiry. There is deliberately no second record
# mirroring it: a copy would need keeping in step, and the window in which it was
# out of step would be a subscriber locked out or a lapsed one still reading.
#
# Saved vocabulary is outside all of this by design. `phrase_token_users` belongs
# to the learner, not to the channel the words were met in, so a lapsed
# subscriber keeps every word they saved and can still take review lessons.
class ProChannel < Channel
  NAME = "Pro Library".freeze

  # Private, always. The two other visibilities would both be wrong in ways the
  # subscriber could not undo: public would publish their imports to the world,
  # and shared would invite strangers into a library that is not really theirs to
  # share.
  validates :visibility, inclusion: { in: [ "private" ] }
  validate :never_a_default_channel

  # This class's contribution to Channel.visible_to: its subscriber's rows while
  # they are entitled, and nothing at all when they are not. Returning nil rather
  # than `none` keeps the grant out of the OR chain entirely — a `none` subquery
  # is a needless `WHERE 1=0` branch in a query that runs on every listing.
  def self.owned_grant(user)
    return nil unless user.pro?

    where(user_id: user.id)
  end

  # Ownership alone is not enough here, which is the whole point of the class.
  def readable_by?(actor)
    return false unless actor
    return true if actor.admin?

    actor.id == user_id && actor.pro?
  end

  # There is no visibility a Pro library could legitimately move to, and no actor
  # who should be able to move it — an administrator included. Making it public
  # would expose one person's private imports; making it shared would let the
  # subscriber hand out access that outlives their subscription.
  def change_visibility!(_new_visibility, actor: nil)
    raise UnauthorizedTransition, "a Pro library's visibility is fixed"
  end

  private

  # Free — and this one line is the whole of "Pro imports are not metered".
  #
  # Everything a subscriber imports is published here (User#publishing_channel)
  # and Channel#publish! is the only thing that spends a credit, so there is no
  # second code path that has to remember to skip the meter, and no way for the
  # import service to charge a subscriber by forgetting to ask whether they are
  # one.
  def charge_for!(_course)
    nil
  end

  def never_a_default_channel
    errors.add(:default, "a Pro library is not a default channel") if default?
  end
end
