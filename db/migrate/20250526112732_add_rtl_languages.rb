class AddRtlLanguages < ActiveRecord::Migration[8.0]
  def change
    add_column :languages, :rtl, :boolean, default: true
  end
end
