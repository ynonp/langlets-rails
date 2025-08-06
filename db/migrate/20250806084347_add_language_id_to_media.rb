class AddLanguageIdToMedia < ActiveRecord::Migration[8.0]
  def change
    add_reference :media, :language
  end
end
