# A Course is readable only through a Channel the reader can see (see
# Course#readable_by?), so any test that renders course content — the course
# page, a lesson, the full player — has to publish it somewhere visible first.
# Creating a Course with `status: :published` is not enough: that is a pipeline
# state, not a visibility rule.
#
# Publishing into an ordinary Channel spends one of the owner's credits — see
# Channel#publish! — and these helpers exist to arrange *visibility*, not to
# exercise billing. So each one covers the credit it is about to spend, leaving
# the owner's balance exactly where it found it. A rendering test that happens to
# need six published courses must not fail because the sixth one was too
# expensive; a test that means to say something about credits should call
# Imports::Create or Channel#publish! itself.
module ChannelPublishingHelpers
  # Publishes to the owner's default Channel and makes that Channel public, so
  # the Course is readable by everyone including signed-out visitors. Use this
  # when the test is about something other than access control.
  def publish_publicly(course, owner: course.user)
    channel = owner.provision_default_channel!
    channel.update!(visibility: :public)
    publish_covering_the_credit(channel, course)
    course
  end

  # Publishes into the one globally listed Channel. The administrator must
  # already exist because Channel.system deliberately never invents an account.
  # System publication is platform curation and does not spend a credit.
  def publish_system(course)
    Channel.system.publish!(course)
    course
  end

  # Publish into a Channel the test already has, on the same terms: the owner's
  # balance is left exactly as it was found. Use this anywhere a test publishes
  # only so that something is readable.
  def publish_covering_the_credit(channel, course)
    return channel.publish!(course) if channel.is_a?(SystemChannel) || channel.is_a?(ProChannel)

    User.where(id: channel.user_id).update_all([ "credit_balance = credit_balance + ?", Imports::Pricing::CREDIT_COST ])
    channel.publish!(course).tap { channel.user.reload }
  end

  # Publishes to the owner's default Channel and leaves it private, so the
  # Course is readable by its owner (and admins) but by nobody else.
  def publish_privately(course, owner: course.user)
    channel = owner.provision_default_channel!
    channel.update!(visibility: :private)
    publish_covering_the_credit(channel, course)
    course
  end
end

module ActiveSupport
  class TestCase
    include ChannelPublishingHelpers
  end
end
