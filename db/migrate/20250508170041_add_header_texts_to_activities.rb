class AddHeaderTextsToActivities < ActiveRecord::Migration[8.0]
  def change
    add_column :activities, :text_header, :string
    add_column :activities, :text_subheader, :string
  end
end
