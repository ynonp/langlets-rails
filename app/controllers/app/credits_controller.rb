module App
  # Screen 06 — Apple in-app purchases in the native shell.
  class CreditsController < BaseController
    def show
      @balance = current_user.credit_balance
      @spent = current_user.credit_ledger_entries.import_spend.count
      @apple_credit_packs = Apple::CreditPacks.all
      @apple_app_account_token = Apple::AppAccountToken.for(current_user)
    end
  end
end
