class AddTimestampsToTokenTranslations < ActiveRecord::Migration[8.0]
  def change
    add_column :token_translations, :start_timestamp, :string
    add_column :token_translations, :end_timestamp, :string
  end
end
