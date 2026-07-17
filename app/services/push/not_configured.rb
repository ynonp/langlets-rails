module Push
  # Its own file so Zeitwerk can autoload it — declaring an error class inside
  # another class's file means `rescue Push::NotConfigured` raises NameError for
  # any caller that hasn't already loaded apns_client.rb. See
  # Credits::InsufficientCredits for the full story.
  class NotConfigured < StandardError; end
end
