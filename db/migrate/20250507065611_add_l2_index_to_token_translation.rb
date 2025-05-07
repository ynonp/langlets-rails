class AddL2IndexToTokenTranslation < ActiveRecord::Migration[8.0]
  def change
    rename_column :token_translations, :start_index, :l1_start_index
    rename_column :token_translations, :end_index, :l1_end_index
    add_column :token_translations, :l2_start_index, :integer
    add_column :token_translations, :l2_end_index, :integer    
  end
end
