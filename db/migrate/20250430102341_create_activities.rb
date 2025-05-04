class CreateActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :activities do |t|
      t.references :lesson, null: false, foreign_key: true
      t.integer :order
      t.string :type

      t.timestamps
    end
  end
end
