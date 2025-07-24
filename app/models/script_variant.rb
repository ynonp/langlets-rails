class ScriptVariant < ApplicationRecord
  belongs_to :multi_script_text
  belongs_to :script

  validates :content, presence: true
  validates :script_id, uniqueness: { scope: :multi_script_text_id }
end