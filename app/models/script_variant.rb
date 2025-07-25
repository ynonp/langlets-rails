class ScriptVariant < ApplicationRecord
  belongs_to :multi_script_text
  belongs_to :script
end
