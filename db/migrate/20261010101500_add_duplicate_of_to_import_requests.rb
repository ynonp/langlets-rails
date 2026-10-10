class AddDuplicateOfToImportRequests < ActiveRecord::Migration[8.0]
  def change
    add_reference :import_requests, :duplicate_of,
      foreign_key: { to_table: :import_requests, on_delete: :nullify }
  end
end
