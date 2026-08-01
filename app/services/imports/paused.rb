module Imports
  # "This is yours, but your subscription has stopped lending it to you."
  #
  # Imports::Preview and Imports::Create both dedupe against published courses,
  # and both used to ask only "is it published?". For your own imports that used
  # to be the same question as "can you read it?" — a course you imported lived
  # in your default Channel forever. A Pro library is revocable, so the two came
  # apart, and pasting a link to your own paused course produced "already in your
  # library" plus an Open button that 404s.
  #
  # One definition, used by both, so the sheet and the thing it triggers cannot
  # disagree about which state the user is in.
  class Paused
    def self.for?(user:, course:)
      return false if user.nil? || course.nil?
      return false if course.readable_by?(user)

      pro_channel = user.pro_channel
      return false if pro_channel.nil?

      pro_channel.channel_items.exists?(course_id: course.id)
    end
  end
end
