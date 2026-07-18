class Current < ActiveSupport::CurrentAttributes
  attribute :translation_language

  def translation_language_id
    translation_language&.id
  end
end
