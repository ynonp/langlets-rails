# app/models/concerns/has_slug.rb
module FriendlyName
  extend ActiveSupport::Concern

  def to_param
    slug.presence || super
  end
end

