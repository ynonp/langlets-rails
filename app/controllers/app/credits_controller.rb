module App
  # Screen 06 — but deliberately not as mocked.
  #
  # The mockup shows three IAP packs and a "Get 15 credits" button. StoreKit is
  # deferred, so all of that would be a control that does nothing. This is an
  # honest dead end instead: you started with 3, they're gone, and there is no way
  # to buy more yet. When purchases land, the packs come back here.
  class CreditsController < BaseController
    def show
      @balance = current_user.credit_balance
      @spent = current_user.credit_ledger_entries.import_spend.count
    end
  end
end
