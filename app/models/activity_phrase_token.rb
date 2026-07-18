class ActivityPhraseToken < ApplicationRecord
  belongs_to :activity
  belongs_to :phrase_token
end
