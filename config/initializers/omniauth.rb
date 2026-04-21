# OmniAuth 2.0+ blocks GET requests to /auth/:provider by default for CSRF protection.
# Our native iOS app uses ASWebAuthenticationSession, which can only navigate via GET.
# We allow both POST (web flow via button_to) and GET (native flow via ASWebAuthenticationSession).
# The web flow remains protected by Rails CSRF tokens through button_to.
OmniAuth.config.allowed_request_methods = [:post, :get]
