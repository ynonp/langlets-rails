class AddPreferredLanguageToUsers < ActiveRecord::Migration[8.0]
  # Reconciles db/schema.rb with db/migrate. users.preferred_language_id has been
  # in the schema since 9133184 with no migration behind it; the original
  # migration ran locally and its file was never committed.
  #
  # Guarded because databases built with db:schema:load already have the column
  # but not this version, and would otherwise fail on the next deploy.
  def change
    return if column_exists?(:users, :preferred_language_id)

    add_reference :users, :preferred_language, foreign_key: { to_table: :languages }
  end
end
