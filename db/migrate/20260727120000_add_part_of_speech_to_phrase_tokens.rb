class AddPartOfSpeechToPhraseTokens < ActiveRecord::Migration[8.0]
  def change
    add_column :phrase_tokens, :part_of_speech, :string
    add_index :phrase_tokens, :part_of_speech
  end
end
