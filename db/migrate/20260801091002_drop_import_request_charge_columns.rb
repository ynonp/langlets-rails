# Charging moved to Channel#publish!, which is the moment a course becomes
# somebody's. That made all three of these columns dead:
#
#   charged     — "a credit moved for this request". The ledger says so, keyed on
#                 the (channel, course) pair; the boolean was a second copy of a
#                 fact that now belongs to the publication rather than to the
#                 request that asked for it.
#   refunded    — nothing to refund. A failed import never published, so it never
#                 charged, and Imports::Settlement#fail! no longer moves credits.
#   pro_covered — "the user paid by subscribing". Only Settlement read it, to tell
#                 an importer from a free rider when choosing an enrollment
#                 source. There are no free riders any more: every ImportRequest
#                 ends in a publication into its own user's channel.
#
# No history is lost. credit_ledger_entries remains the append-only record of
# every credit that has ever moved, including the ones these columns mirrored.
class DropImportRequestChargeColumns < ActiveRecord::Migration[8.0]
  def change
    remove_column :import_requests, :charged, :boolean, default: false, null: false
    remove_column :import_requests, :refunded, :boolean, default: false, null: false
    remove_column :import_requests, :pro_covered, :boolean, default: false, null: false
  end
end
