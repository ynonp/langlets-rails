class MultiScriptText < ApplicationRecord
  belongs_to :language
  has_many :script_variants, dependent: :destroy

  # Find or create a script variant for a specific script
  def variant_for_script(script)
    script_variants.find_by(script: script)
  end

  # Get content for the default script of the language
  def default_content
    variant = variant_for_script(language.default_script)
    variant&.content
  end

  # Get content for a specific script, with fallback to default
  def content_for_script(script)
    variant = variant_for_script(script)
    variant&.content || default_content
  end
end