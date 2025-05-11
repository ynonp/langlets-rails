class AddPronunciationVariantName < ActiveRecord::Migration[8.0]
  def change
    add_column :languages, :pronunciation_variant_name, :string
  end
end
