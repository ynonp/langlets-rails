# frozen_string_literal: true

# A single-use ticket that moves a just-authenticated session from the browser
# into the native app's own web view.
#
# **Why this exists.** On Android, OAuth with GitHub or Apple cannot complete
# inside the app's WebView the way it does on iOS. The provider's consent page
# is a different host, so Hotwire's browser-tab route decision handler lifts it
# into a Chrome Custom Tab — and a Custom Tab's cookies belong to Chrome, not to
# this app. The callback therefore arrives in a different cookie jar from the
# one the request phase wrote `omniauth.state` into, and any session it did
# establish would be Chrome's. iOS has no such split: its
# `ASWebAuthenticationSession` shares a cookie jar with `WKWebsiteDataStore`,
# which is exactly the thing Android has no equivalent of.
#
# So the flow is deliberately run *entirely* in the Custom Tab — request phase
# and callback in the same jar, which is what makes state and nonce checks work
# again — and the resulting session is carried back across the jar boundary by
# hand, as one of these.
#
# **Why it is safe to carry.** The token travels to the app over a `langlets://`
# deep link, and a custom scheme is not exclusive: another installed app can
# register it and receive the redirect. So the token alone is not sufficient.
# Before opening the Custom Tab the app generates a random verifier, keeps it,
# and sends only `challenge = base64url(SHA-256(verifier))`; redemption must
# present the verifier itself. That is RFC 7636's S256 construction, used here
# for the same reason it exists there — an interceptor gets a value it cannot
# use. On top of that: 256 bits of entropy, [TTL] seconds to live, and exactly
# one successful redemption, enforced by the delete in [redeem].
class NativeAuthHandoff < ApplicationRecord
  belongs_to :user

  # Long enough for the app to be brought to the foreground by the deep link and
  # issue one request, short enough that a token recovered from a log or a
  # process dump is almost always already dead.
  TTL = 2.minutes

  # base64url of a SHA-256 digest, unpadded.
  CHALLENGE_FORMAT = /\A[A-Za-z0-9_-]{43}\z/

  validates :token_digest, presence: true, uniqueness: true
  validates :challenge, presence: true, format: { with: CHALLENGE_FORMAT }
  validates :expires_at, presence: true

  scope :expired, -> { where(expires_at: ..Time.zone.now) }

  # Mints a token for +user+ bound to +challenge+ and returns it. The raw token
  # is returned and never stored; this is the only moment it exists.
  def self.issue!(user, challenge)
    token = SecureRandom.urlsafe_base64(32)

    create!(
      user: user,
      token_digest: digest(token),
      challenge: challenge,
      expires_at: TTL.from_now
    )

    expired.delete_all

    token
  end

  # Spends +token+ and returns the user it was minted for, or nil.
  #
  # The delete is the gate, not a cleanup afterwards: `delete_all` reports how
  # many rows it actually removed, so two concurrent redemptions of the same
  # token cannot both see 1 and both sign someone in. Everything else is checked
  # before it, and the row is gone either way once we have decided to consider
  # it — a token that fails the verifier check is burned rather than left for
  # another attempt.
  def self.redeem(token, verifier)
    return nil if token.blank? || verifier.blank?

    handoff = find_by(token_digest: digest(token))
    return nil if handoff.nil?

    return nil unless where(id: handoff.id).delete_all == 1
    return nil if handoff.expires_at <= Time.zone.now
    return nil unless ActiveSupport::SecurityUtils.secure_compare(handoff.challenge, challenge_for(verifier))

    handoff.user
  end

  # The commitment the app sends when it opens the browser. Kept here so the one
  # place that verifies it and any test that fakes it agree by construction.
  def self.challenge_for(verifier)
    Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false)
  end

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end
  private_class_method :digest
end
