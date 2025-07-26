class ScriptVariant < ApplicationRecord
  belongs_to :multi_script_text
  belongs_to :script
  
  after_save :clear_parent_caches
  after_destroy :clear_parent_caches
  
  private
  
  def clear_parent_caches
    multi_script_text.send(:clear_caches!) if multi_script_text
  end
end
