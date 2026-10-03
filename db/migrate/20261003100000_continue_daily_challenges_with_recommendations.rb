class ContinueDailyChallengesWithRecommendations < ActiveRecord::Migration[8.0]
  def change
    remove_check_constraint :daily_challenges, name: "daily_challenge_day_range", expression: "day >= 1 AND day <= 5"
    add_check_constraint :daily_challenges, "day >= 1", name: "daily_challenge_positive_day"
    add_reference :daily_challenges, :language, foreign_key: true
    add_column :daily_challenges, :recommended_video, :jsonb, default: {}, null: false
    add_column :daily_challenges, :recommendation_state, :string, default: "pending", null: false
    add_column :daily_challenges, :search_started_at, :datetime
    add_column :daily_challenges, :search_attempts, :integer, default: 0, null: false
    add_column :daily_challenges, :recommendation_failure, :string
  end
end
