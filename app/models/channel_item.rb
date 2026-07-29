class ChannelItem < ApplicationRecord
  belongs_to :channel
  belongs_to :course

  validates :published_at, presence: true
end
