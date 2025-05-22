class Course < ApplicationRecord
  has_many :lessons, -> { order(order: :asc) }, dependent: :destroy
end
