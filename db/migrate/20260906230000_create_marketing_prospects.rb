class CreateMarketingProspects < ActiveRecord::Migration[8.0]
  def change
    create_table :prospects do |t|
      t.string :email, null: false
      t.string :locale, null: false, default: "en"
      t.string :utm_source
      t.references :course, foreign_key: { on_delete: :nullify }
      t.references :lesson, foreign_key: { on_delete: :nullify }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.datetime :activated_at
      t.datetime :invitation_sent_at
      t.datetime :admin_notified_at
      t.timestamps
    end
    add_index :prospects, "lower(email)", unique: true
  end
end
