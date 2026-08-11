class AddGuestStartedToImportRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :import_requests, :guest_started, :boolean, null: false, default: false
  end
end
