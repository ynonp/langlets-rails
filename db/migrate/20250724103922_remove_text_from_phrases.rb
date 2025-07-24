class RemoveTextFromPhrases < ActiveRecord::Migration[8.0]
  def change
    remove_column :phrases, :text_l1, :string
    remove_column :phrases, :text_l2, :string
  end
end
