class Script < ApplicationRecord
  has_many :languages, foreign_key: 'default_script_id', dependent: :nullify
  has_many :script_variants, dependent: :destroy
  
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
