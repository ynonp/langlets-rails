class CreateNativeMutationReceipts < ActiveRecord::Migration[8.0]
  def change
    create_table :native_mutation_receipts do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.uuid :operation_id, null: false
      t.string :payload_digest, null: false
      t.jsonb :result, null: false, default: {}
      t.timestamps
    end
    add_index :native_mutation_receipts, [ :user_id, :operation_id ], unique: true
  end
end
