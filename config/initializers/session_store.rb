Rails.application.config.session_store :cookie_store,
  key: "_langlets_session",
  domain: :all,
  tld_length: 2
