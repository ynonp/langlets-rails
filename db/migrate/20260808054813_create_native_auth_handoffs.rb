class CreateNativeAuthHandoffs < ActiveRecord::Migration[8.0]
  def change
    create_table :native_auth_handoffs do |t|
      t.references :user, null: false, foreign_key: true

      # SHA-256 of the token, never the token itself: this row is a live
      # credential for the user's session, and a database leak should not hand
      # anyone a working one.
      t.string :token_digest, null: false
      # The app's PKCE-style commitment, base64url(SHA-256(verifier)). Redeeming
      # requires producing the verifier, so intercepting the deep link that
      # carries the token is not enough on its own.
      t.string :challenge, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :native_auth_handoffs, :token_digest, unique: true
    add_index :native_auth_handoffs, :expires_at
  end
end
