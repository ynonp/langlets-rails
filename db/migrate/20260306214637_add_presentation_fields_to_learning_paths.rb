class AddPresentationFieldsToLearningPaths < ActiveRecord::Migration[8.0]
  # Reconciles db/schema.rb with db/migrate. These columns have been in the
  # schema since 4554089 with no migration behind them; the original migration
  # ran locally and its file was never committed.
  #
  # Guarded because databases built with db:schema:load already have the columns
  # but not this version, and would otherwise fail on the next deploy.
  def change
    add_column :learning_paths, :subtitle, :string unless column_exists?(:learning_paths, :subtitle)
    add_column :learning_paths, :hero_image_url, :string unless column_exists?(:learning_paths, :hero_image_url)
    add_column :learning_paths, :cta_text, :string unless column_exists?(:learning_paths, :cta_text)
    add_column :learning_paths, :cta_link, :string unless column_exists?(:learning_paths, :cta_link)
    add_column :learning_paths, :primary_color, :string unless column_exists?(:learning_paths, :primary_color)

    unless column_exists?(:learning_paths, :layout_style)
      add_column :learning_paths, :layout_style, :string, default: "default"
    end

    add_column :learning_paths, :slug, :string unless column_exists?(:learning_paths, :slug)
  end
end
