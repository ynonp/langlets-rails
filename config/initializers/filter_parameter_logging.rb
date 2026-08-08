# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # The native sign-in handoff sends its PKCE verifier in the query string (a
  # web view can only issue a GET), and `token` above already covers the other
  # half. Both are single-use and short-lived, but a request line is the one
  # place a credential survives longest, so neither belongs in a log.
  :verifier
]
