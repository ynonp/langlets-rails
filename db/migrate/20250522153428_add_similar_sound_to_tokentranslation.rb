class AddSimilarSoundToTokentranslation < ActiveRecord::Migration[8.0]
  def change
    add_column :token_translations, :similar_sound, :string, array: true
  end
end
