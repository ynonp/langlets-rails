# Native iOS API and offline contract

The machine-readable contract is [OpenAPI 3.1](openapi.json). Routes are additive
under `/api/v1/native`; web, Android and the existing share API retain their URLs.
All IDs are database integers except course URLs, which use slugs. Clients ignore
unknown response fields. Activity `kind` is an explicit enum: an unknown kind
must invite an app update rather than silently complete it.

## Authentication

`POST session` exchanges confirmed email/password, a Google **server authorization
code**, or an existing single-use PKCE `NativeAuthHandoff` for a Doorkeeper token.
Google's code is exchanged server-side with the configured client secret and the
verified-email claim is required. Apple/GitHub use `ASWebAuthenticationSession`
with the existing PKCE handoff; no shared browser cookies are assumed.

The fixed public client is `langlets-ios-native-v1`. Access tokens expire after
two hours; refresh through `/oauth/token` with `grant_type=refresh_token`,
`client_id`, and `refresh_token`. Refresh is coalesced on the client. Main-app
credentials have `native imports:read imports:write credits:read` scopes and use
a private, device-only Keychain item. Every protected native endpoint requires
`native`; the old read-only course/vocabulary scopes cannot mutate accounts.
HTTP cookies are never an alternative to bearer authorization.

`POST extension_token` issues/reuses the existing 30-day, narrowly scoped
`imports:read imports:write credits:read` token in the shared Keychain. The share
extension continues to use `/api/v1/import_requests`. It never receives the
native scope or refresh credential. Sign-out revokes the current native token,
revokes account share-extension tokens, removes the supplied installation token,
and clears the local account cache and Keychain. Sign-out requires a successful
online revocation; pending changes are discarded only after explicit confirmation.

`registration`, `password`, `confirmation`, and `onboarding` are public and
rate-limited per IP. Registration retains Devise email confirmation. Password
reset and confirmation links can open native forms through the AASA document at
`/.well-known/apple-app-site-association`; browser fallback remains available.
Successful password reset revokes the account's existing OAuth credentials.
A migration from a Hotwire installation requires signing in once: its limited
share token cannot be promoted into full account access.

## Reading

`bootstrap` returns account status, supported languages, review languages and
server time. Account preference sets both I18n and `Current.translation_language`.
Lists contain at most 40 items plus nullable `next_page`; pages are not complete
snapshots of the account. Courses are filtered through `ChannelContentQuery`;
playlist membership and enrollment never grant read access by themselves.
Inaccessible resources return 404. Responses have `Cache-Control: no-store`;
the native app deliberately owns its protected cache instead of relying on the
HTTP cache or browser history.

`courses/:slug/download` returns course metadata, the complete medium transcript,
and ordered lesson bundles. Each lesson includes explicit phrase/token spans,
translations, timing in seconds, provider identity, activity memberships and
completion IDs. Token indexes are inclusive **Unicode scalar** offsets, matching
Ruby character indexing, not Swift grapheme or UTF-16 offsets. Phrase text has no
persisted audio attachment in the current schema. Token audio descriptors carry
Active Storage blob ID, URL, byte size and base64 MD5 checksum. Downloads verify
both size and checksum before atomically publishing an audio file.

Lessons have a seven-day `offline_until` lease. The client checks it before using
a downloaded lesson/transcript, rechecks course readability online, and removes
revoked downloads on 404. This bounds revocation delay; it is not DRM and cannot
make already-delivered data secret again. Saved vocabulary remains independent
of course entitlement, matching the existing product rules. Offline provider
video is unavailable; transcript, exercises, downloaded token audio and available
system pronunciation voices work locally.

## Durable mutations

`POST mutations` accepts one `operation_id` UUID and immutable `payload`.
The server locks the account, validates access, applies the change, and records
its result and SHA-256 digest in `native_mutation_receipts` in one transaction.
Replay returns the recorded result; reuse of a UUID with another payload returns
409. Receipts persist until account deletion. Clients must persist UUID and
payload **before** reporting success locally and keep both unchanged on retry.

| Kind | Required payload | Semantics |
|---|---|---|
| activity_complete | activity_id | Authorized lesson; first completion awards server-computed XP |
| lesson_complete | lesson_id | Idempotent completion/enrollment; completes a review and schedules its successor |
| word_save | token_id | Existing saved token, own custom phrase, or currently readable course token |
| word_remove | token_id | Remove only this user's saved link |
| word_update | entry_id, practicing and/or translation | Explicit boolean; saved-word translation correction matches the existing web editor (shared TokenTranslation) |
| word_create | sentence, language, token_start, token_end, translation | Word indexes select a span in normalized whitespace; delegates to existing custom vocabulary service |
| notification_read | optional notification_id | One owned notification or all owned notifications |
| challenge_complete | day | Account/current-local-day validation through DailyChallenge |

The server never accepts client XP. A second UUID for an already-completed
activity or lesson also awards no XP. Optional ISO 8601 `occurred_at` preserves
offline practice dates for completion records and XP logs, bounded to the past
seven days and the current server time. Older queued practice counts at that bound.
Challenges that become stale while offline fail visibly instead of completing a
different day's quest.

The client retries transport failures, 5xx and rate limits on reconnect/foreground
or explicit Sync. 401 triggers one refresh and then reauthentication while retaining
queued changes. 403/404/409/422 put the operation into the visible failed list;
these do not block unrelated queued operations. Users can discard a failed change.
Pending vocabulary changes are layered on cached pages, and a confirmed mutation
refreshes those pages before its local overlay is removed.

Imports keep their existing `client_token` idempotency contract. Import creation,
sharing, course reset/delete, playlist changes, credentials and account deletion
are explicit online actions. They never claim success from a local queue.

## Operations and rollout

Apply `20260925110000_create_native_mutation_receipts` before running the client.
Existing APIs are unchanged. Test with:

```sh
./bin/rails test test/controllers/api/v1 test/integration/course_access_test.rb test/controllers/configurations_controller_test.rb
swift test --package-path langlets-ios
xcodebuild -project langlets-ios/langlets/langlets.xcodeproj -scheme langlets \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/ios CODE_SIGNING_ALLOWED=NO build
```

The existing manual mobile build workflow now runs the Swift model tests before
building the app and extension. Associated Domains must be enabled in the Apple
app's provisioning profile and the AASA endpoint deployed before universal links
can be device-tested. Do not release solely on the Rails tests: see the
[implementation status and device checklist](implementation-status.md).
