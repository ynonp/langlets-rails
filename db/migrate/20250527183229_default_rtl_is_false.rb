class DefaultRtlIsFalse < ActiveRecord::Migration[8.0]
  def up
    change_column_default :languages, :rtl, false
    execute "UPDATE languages SET rtl = false WHERE iso_name in ('en', 'fr', 'es');"
  end

  def down
    change_column_default :languages, :rtl, true
    execute "UPDATE languages SET rtl = false WHERE iso_name in ('en', 'fr', 'es');"
  end
end
