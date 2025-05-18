class ActivityTokenTranslation < ApplicationRecord
  belongs_to :activity
  belongs_to :token_translation
end
