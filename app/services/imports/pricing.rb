module Imports
  # What an import costs, and whether this user can afford one.
  #
  # It does **not** take payment. `Channel#publish!` does, because publishing is
  # the thing being sold:
  #
  #   publishing a course into a default Channel costs one credit
  #   publishing a course into a Pro library costs nothing
  #
  # Who executed the pipeline, and whether it ran a minute ago or a year ago,
  # does not enter into it — a course somebody else imported is not yours until
  # it is published into your channel. This is why there is no longer a free
  # "deduped" hand-over of a finished course, and no free ride on somebody else's
  # in-flight run: both end with a course in the user's channel.
  #
  # The one free case is a publication that has already happened: re-importing
  # something already sitting in your own channel, ready in the language you
  # asked for, publishes nothing, so it costs nothing.
  #
  # This module exists so the Add Video sheet can quote that price before Approve
  # is tapped, and so a pipeline is never started for a result the user will not
  # be able to take delivery of.
  module Pricing
    CREDIT_COST = 1

    module_function

    # What Approve will cost this user. `course` is the Course this import would
    # end up publishing, or nil when nothing exists for this video yet.
    def cost_for(user:, course: nil)
      return 0 if free_for?(user)
      return 0 if already_published?(user: user, course: course)

      CREDIT_COST
    end

    # A subscriber publishes to their Pro library, which the subscription has
    # already paid for. Deliberately the same predicate that chooses the channel
    # (User#publishing_channel), so the quote and the destination cannot disagree.
    def free_for?(user)
      user.pro?
    end

    # Already sitting in the channel this import would publish into. The credit
    # buys a ChannelItem, so once there is one there is nothing left to buy —
    # including for a second translation of a course already in the channel,
    # which publishes nothing new and therefore costs nothing.
    #
    # Asked of exactly the channel Channel#publish! will reach for, not of "any
    # channel of theirs", because that is the row whose absence decides the
    # charge. Quoting anything else would let the sheet and the till disagree.
    def already_published?(user:, course:)
      return false if course.nil?

      channel = destination_channel(user)
      return false if channel.nil?

      channel.channel_items.exists?(course_id: course.id)
    end

    # Where this user's next import lands — User#publishing_channel without the
    # provisioning. Imports::Preview must not create a Pro library for somebody
    # merely by being looked at, and a channel that does not exist yet holds
    # nothing, which is the answer we want anyway.
    def destination_channel(user)
      free_for?(user) ? user.pro_channel : user.default_channel
    end

    # Refuse an import the user will not be able to pay for when it lands.
    #
    # Nothing is charged until publication, so this is a guard and not a
    # reservation. It exists for two reasons: to keep us from running a pipeline
    # whose result has to be thrown away, and to give the Add Video sheet and the
    # share-extension API the Credits::InsufficientCredits they already handle at
    # the moment the user can still do something about it.
    #
    # It counts what is already in flight, because every one of those wants a
    # credit of its own when it publishes. Without that, one credit would let a
    # user queue any number of imports and only the first could be delivered.
    #
    # `cost` is required rather than defaulted, because the one thing this must
    # never do is refuse an import that was free: a defaulted price would turn
    # every forgotten argument into a paywall in front of a Pro subscriber.
    #
    # `excluding` is the request being promoted out of language detection: it is
    # already active, and would otherwise be counted twice.
    def ensure_affordable!(user, cost:, excluding: nil)
      return if cost.zero?

      committed = user.import_requests.active.where.not(id: excluding).count + cost
      balance = User.where(id: user.id).pick(:credit_balance).to_i
      return if balance >= committed

      raise Credits::InsufficientCredits,
            "user #{user.id} has #{balance} credits and #{committed} imports to pay for"
    end
  end
end
