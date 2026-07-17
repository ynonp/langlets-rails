module Credits
  # Its own file so Zeitwerk can autoload it.
  #
  # This used to be declared inside credits/ledger.rb. Zeitwerk only registers an
  # autoload for the constant matching the file name (Credits::Ledger), so
  # Credits::InsufficientCredits existed only as a side effect of that file having
  # been loaded. Any `rescue Credits::InsufficientCredits` reached without the
  # ledger having been touched — an unavailable video, say — raised NameError
  # instead. Production hid it (eager loading defines everything at boot) and so
  # did the test suite (an earlier test had already loaded the ledger).
  class InsufficientCredits < StandardError; end
end
