class IndexSubscriptionsOnStatusAndExpiry < ActiveRecord::Migration[8.0]
  # ExpireSubscriptionsJob sweeps `status_active AND expires_at < now` across the
  # whole table. The existing index leads on user_id, which cannot serve a query
  # with no user in it, so that sweep is a sequential scan.
  #
  # Precautionary rather than measured: `subscriptions` holds roughly one row per
  # subscriber and the job runs daily, so this is not fixing an observed problem.
  # It is cheap, and the table only ever grows — rows are never deleted, and a
  # user who resubscribes after a lapse accumulates another.
  def change
    add_index :subscriptions, [ :status, :expires_at ]
  end
end
