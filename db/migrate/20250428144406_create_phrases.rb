class CreatePhrases < ActiveRecord::Migration[8.0]
  def change
    create_table :phrases do |t|
      t.references :medium, null: false, foreign_key: true
      t.references :l1, null: false, foreign_key: { to_table: :languages }
      t.references :l2, null: false, foreign_key: { to_table: :languages }
      t.string :text_l1
      t.string :text_l2
      t.string :timestamp

      t.timestamps
    end
  end
end
