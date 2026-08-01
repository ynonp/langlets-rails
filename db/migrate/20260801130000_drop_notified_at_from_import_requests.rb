# `notified_at` was the idempotency stamp for the old "your course is ready"
# push, which sent straight from ImportRequest. Notifications owns that now, and
# the Notification row is what makes delivery happen once — the stamp was a
# second copy of a fact that has moved.
#
# Dropped rather than ignored because the pipeline stops before this deploy, so
# no container is left running code that still writes the column.
class DropNotifiedAtFromImportRequests < ActiveRecord::Migration[8.0]
  def change
    remove_column :import_requests, :notified_at, :datetime
  end
end
