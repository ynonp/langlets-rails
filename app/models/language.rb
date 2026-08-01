class Language < ApplicationRecord
  # The languages offered on the native onboarding screen. Deliberately narrower
  # than the table: every language in `languages` can be a *translation*
  # language (the subdomain picks it) or carry legacy courses, but a new user is
  # only asked to choose between the three we have enough content to teach.
  ONBOARDING_ISO_NAMES = %w[fr es ar-JO].freeze

  belongs_to :default_script, class_name: 'Script', optional: true
  has_many :courses, dependent: :destroy
  has_many :phrases_as_l1, class_name: 'Phrase', foreign_key: 'l1_id', dependent: :destroy
  has_many :phrases_as_l2, class_name: 'Phrase', foreign_key: 'l2_id', dependent: :destroy

  scope :onboarding_options, -> { where(iso_name: ONBOARDING_ISO_NAMES) }
end
