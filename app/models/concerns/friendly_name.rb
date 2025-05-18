# app/models/concerns/has_slug.rb
module FriendlyName
  extend ActiveSupport::Concern

  included do
    validates :slug, presence: true, uniqueness: true
  end

  def to_param
    slug.presence || super
  end
end

