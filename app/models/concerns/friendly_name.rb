# app/models/concerns/has_slug.rb
module FriendlyName
  extend ActiveSupport::Concern

  included do
    validates :slug, presence: true
    # Uniqueness validation is handled at the model level with scope
  end

  def to_param
    slug.presence || super
  end
end

