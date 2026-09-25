# Retained for the account lifetime: old offline writes must never replay as new.
class NativeMutationReceipt < ApplicationRecord
  belongs_to :user
end
