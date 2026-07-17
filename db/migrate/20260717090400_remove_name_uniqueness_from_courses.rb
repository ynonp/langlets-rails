class RemoveNameUniquenessFromCourses < ActiveRecord::Migration[8.0]
  # courses.name was globally unique, which was fine when one admin typed every
  # title by hand. Once any user can import a video, two people importing
  # different videos that happen to share a title would collide on a field that
  # isn't an identifier — `slug` is (uniquely indexed, and what FriendlyName#to_param
  # returns). A global unique index on a human title in a community catalog only
  # produces spurious failures.
  #
  # Nothing looks a course up by name; the index served only the constraint.
  def up
    remove_index :courses, :name
  end

  def down
    add_index :courses, :name, unique: true
  end
end
