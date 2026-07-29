class BackfillLegacyCoursesToDefaultChannels < ActiveRecord::Migration[8.0]
  def up
    # ImportRequest-backed courses were handled by CreateChannels using the
    # requester's identity and earliest successful request timestamp. Courses
    # created before ImportRequest existed have no such publishing record. For
    # those rows only, the historical creator is the sole available identity.
    #
    # NOT EXISTS deliberately checks every Channel, not just the creator's
    # default: a course that was explicitly published anywhere after the first
    # migration must not gain an inferred second contribution.
    execute <<~SQL
      INSERT INTO channel_items (channel_id, course_id, published_at, created_at, updated_at)
      SELECT channels.id, courses.id, courses.created_at, NOW(), NOW()
      FROM courses
      INNER JOIN channels
        ON channels.user_id = courses.user_id AND channels."default" = TRUE
      WHERE courses.status = 1
        AND NOT EXISTS (
          SELECT 1
          FROM channel_items
          WHERE channel_items.course_id = courses.id
        )
      ON CONFLICT (channel_id, course_id) DO NOTHING
    SQL
  end

  def down
    # There is no reliable way to distinguish an inferred legacy row from an
    # identical ChannelItem subsequently affirmed by its owner. Keep user data.
  end
end
