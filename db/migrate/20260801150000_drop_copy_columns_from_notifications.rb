# The copy moves off the row and into the locale files.
#
# `title` and `body` held finished English sentences, written once at creation
# and never recomputed. They are replaced by rendering
# `notifications.kinds.<kind>.*` against the values already stored in `data` —
# which is what makes a copy edit apply to notifications that were already
# sent, and what lets the list render in the reader's language.
#
# No backfill: this subsystem has not shipped, and the table it replaced was
# asserted empty by CreateNotifications' own row-count guard. There is nothing
# to convert — which is the only reason this is cheap. Once real rows exist the
# sentences cannot be taken apart again into the values that built them.
class DropCopyColumnsFromNotifications < ActiveRecord::Migration[8.0]
  def change
    remove_column :notifications, :title, :string, null: false
    remove_column :notifications, :body, :string, null: false
  end
end
