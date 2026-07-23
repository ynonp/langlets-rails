module App
  # Screen 06 — shared by the native shell and web browsers because PayPal
  # checkout and its return URL are ordinary web navigation.
  class CreditsController < BaseController
    skip_before_action :require_native_app

    def show
      @balance = current_user.credit_balance
      @spent = current_user.credit_ledger_entries.import_spend.count
      @paypal_client = Paypal::Client.new
      @credit_packs = Paypal::CreditPacks.all
    end
  end
end
