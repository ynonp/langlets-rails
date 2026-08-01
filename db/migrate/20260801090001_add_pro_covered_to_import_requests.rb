class AddProCoveredToImportRequests < ActiveRecord::Migration[8.0]
  # `charged` means "a credit moved", and Imports::Settlement uses it for two
  # different decisions: whether to refund, and whether the enrollment came from
  # importing or from the library. A Pro import is uncharged but is still very
  # much this user's own import, so the two questions stop having one answer and
  # need one column each.
  def change
    add_column :import_requests, :pro_covered, :boolean, null: false, default: false
  end
end
