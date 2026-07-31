# A Course is readable only through a Channel the reader can see (see
# Course#readable_by?), so any test that renders course content — the course
# page, a lesson, the full player — has to publish it somewhere visible first.
# Creating a Course with `status: :published` is not enough: that is a pipeline
# state, not a visibility rule.
module ChannelPublishingHelpers
  # Publishes to the owner's default Channel and makes that Channel public, so
  # the Course is readable by everyone including signed-out visitors. Use this
  # when the test is about something other than access control.
  def publish_publicly(course, owner: course.user)
    channel = owner.provision_default_channel!
    channel.update!(visibility: :public)
    channel.publish!(course)
    course
  end

  # Publishes to the owner's default Channel and leaves it private, so the
  # Course is readable by its owner (and admins) but by nobody else.
  def publish_privately(course, owner: course.user)
    channel = owner.provision_default_channel!
    channel.update!(visibility: :private)
    channel.publish!(course)
    course
  end
end

module ActiveSupport
  class TestCase
    include ChannelPublishingHelpers
  end
end
