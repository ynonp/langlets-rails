class MoveEvaluationSignupOwnershipToUsers < ActiveRecord::Migration[8.0]
  def up
    add_reference :users, :evaluation_signup, index: { unique: true }
    add_foreign_key :users, :evaluation_signups, on_delete: :nullify

    # The product has one onboarding evaluation per account. For rows created
    # under the former has-many model, retain only the newest choice.
    execute <<~SQL.squish
      UPDATE users
      SET evaluation_signup_id = latest.id
      FROM (
        SELECT DISTINCT ON (user_id) id, user_id
        FROM evaluation_signups
        WHERE user_id IS NOT NULL
        ORDER BY user_id, created_at DESC, id DESC
      ) latest
      WHERE users.id = latest.user_id
    SQL

    remove_index :evaluation_signups, [ :user_id, :consumed_at ]
    remove_reference :evaluation_signups, :user, foreign_key: true
  end

  def down
    add_reference :evaluation_signups, :user, foreign_key: true

    execute <<~SQL.squish
      UPDATE evaluation_signups
      SET user_id = users.id
      FROM users
      WHERE users.evaluation_signup_id = evaluation_signups.id
    SQL

    add_index :evaluation_signups, [ :user_id, :consumed_at ]
    remove_foreign_key :users, :evaluation_signups
    remove_reference :users, :evaluation_signup, index: { unique: true }
  end
end
