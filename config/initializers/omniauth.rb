# OmniAuth 2.0+ blocks GET requests to /auth/:provider by default for CSRF protection.
# Our native iOS app uses ASWebAuthenticationSession, which can only navigate via GET.
# We allow both POST (web flow via button_to) and GET (native flow via ASWebAuthenticationSession).
# The web flow remains protected by Rails CSRF tokens through button_to.
OmniAuth.config.allowed_request_methods = [ :post, :get ]

# OAuth providers only need the canonical production callback registered. The
# session cookie is shared across langlets.app subdomains, so a request started
# on he.langlets.app can safely finish on langlets.app and then return to its
# recorded origin. Keep local/test hosts request-scoped for development.
OmniAuth.config.full_host = lambda do |env|
  request = Rack::Request.new(env)

  if %w[langlets.app he.langlets.app].include?(request.host.downcase)
    "https://langlets.app"
  else
    request.base_url
  end
end
