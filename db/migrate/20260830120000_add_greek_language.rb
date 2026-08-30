class AddGreekLanguage < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      INSERT INTO languages
        (iso_name, english_name, native_name, pronunciation_variant_name, rtl, created_at, updated_at)
      VALUES
        ('el', 'Greek', 'Ελληνικά', 'el-GR', FALSE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT (iso_name) DO UPDATE SET
        english_name = EXCLUDED.english_name,
        native_name = EXCLUDED.native_name,
        pronunciation_variant_name = EXCLUDED.pronunciation_variant_name,
        rtl = EXCLUDED.rtl,
        updated_at = CURRENT_TIMESTAMP
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Greek may be referenced by production content and cannot be removed safely"
  end
end
