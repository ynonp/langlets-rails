# Native migration implementation status

## Implemented in this change

`SceneDelegate` now hosts SwiftUI `NativeRoot`. The active iOS navigation has no
Hotwire Navigator or Rails-rendered learner screens. Legacy bridge sources are excluded from the app target and the Hotwire package
dependency is removed; the served and
bundled Hotwire configurations stay identical for installed releases and Android.

The native source includes welcome/beta/language/reminder/video onboarding;
email signup, confirmation and recovery; Google SDK and Apple/GitHub system
browser authentication; four tabs; paginated library and enrolled courses;
course details, sharing, enrollment, translation, reset/remove; course downloads;
playlists and membership; import previews/status/cancellation; saved/custom
vocabulary, pause/resume and undo; notifications; challenges/reminders; profile,
connected clients, invitations and account deletion.

All fourteen persisted activity kinds have Swift presentations. Course and review
lessons share the engine. Reading/transcript, cloze choices/typing/hint, matching,
word construction, chronological ordering, question answering, chained vocabulary,
listening and speech use native controls. Lessons record progress before advancing
and restore their activity position. Speaking uses on-device recognition where
supported, with an explicit practice-aloud/skip path otherwise. The provider-only
WKWebView is separate from navigation; native transcript controls receive player
time and issue pause/seek commands. System voices supplement missing token audio.

Persistence is an account-isolated versioned snapshot in Application Support,
written atomically on an actor with file protection and backup exclusion. Keychain
holds credentials. A durable operation queue retains IDs across restarts and
retries. Downloaded token audio is checksum-verified and uses stable blob IDs.
Collections use bounded pages and course-list progress/ownership is batched.
Large lists/transcripts use lazy SwiftUI containers, and network search is debounced.
Spanish/Hebrew core UI labels and RTL layout are included.

## Remaining parity and release work

This is a substantial implementation, **not a verified production replacement**.
The following differences and validation gaps remain explicit:

- Xcode compilation, Swift test execution, simulator UI tests and physical-device
  checks have not run on the Linux devbox. Syntax parsing is not Swift type checking.
- The former exercise timing/feedback details need side-by-side device acceptance.
  Alignment currently uses token-pair matching; token chains use sequential
  translation prompts. Inline translated spans, timed highlighting and sentence
  pauses are implemented, but provider timing needs physical-device validation.
  These are functional native presentations, not certified visual or pedagogical parity.
- Apple authentication uses the system browser handoff; a native
  `ASAuthorizationAppleIDProvider` flow with a server-bound nonce is still desirable.
- Legal/support documents remain external canonical links. Account deletion for
  social-only accounts currently requires first setting a password via recovery.
- Core labels are translated, but remaining long-form help/error text and dynamic
  interpolation need a complete Spanish/Hebrew localization review.
- Downloads are foreground/resumable, not background URLSession transfers;
  cached review text is available offline but there is no bulk review-audio
  download action. Available iOS voices are the fallback. Snapshots are suitable
  for this first implementation; large-library memory/disk profiling must precede
  a decision on normalized SQLite/SwiftData storage.
- Notifications have explicit read/all actions; the old shell's automatic mark-all-read on every
  foreground has not been carried over. A daily-practice link without a language
  opens challenge settings.
- Guest evaluation imports are not started under the admin account before signup;
  the native onboarding saves the video draft and requests an import preview after
  authentication. This avoids creating a second guest-import protocol, but differs
  from the browser acquisition funnel.

## Device acceptance checklist

- Build main app and extension with current signing identities; test upgrade from
  Hotwire, first sign-in, confirmation on another device, reset, OAuth cancellation,
  expiry/refresh and switching between two accounts.
- Download a course, enter airplane mode, kill/relaunch, complete each activity,
  add/pause/delete/undo vocabulary, reconnect, and confirm one completion/XP award.
- Lose the response after a successful mutation, retry, and inspect receipts.
  Revoke course access elsewhere, refresh, and verify its cached content disappears;
  advance beyond a lease and verify offline lesson access stops.
- Test both provider players: fresh play, pause/seek, segment end, text-only,
  sentence pause, switching activities and closing during playback. Backgrounding
  must not leave unintended audio playing.
- Interrupt an audio download, resume it, simulate disk-full/checksum failure,
  remove a download, and confirm vocabulary pronunciation remains usable.
- Open every inventory destination at large Dynamic Type, with VoiceOver, Reduce
  Motion, landscape, Hebrew RTL and long transcripts. Verify contrast and focus.
- Test APNs warm/cold launch, universal links on all three hosts, share extension
  after changing language/account, and notification opt-out.

## Local validation

Rails integration tests cover native scope isolation, confirmed authentication,
refresh, authorized download bundles, OpenAPI response shapes, replay/conflicting
UUIDs, rollback, client-XP rejection, private token saves, saved vocabulary after
revocation, playlist visibility, preferences and sign-out. Existing API and course
access/routing regressions also pass. The broad regression run passed 80 tests / 263 assertions; the expanded native
suite subsequently passed 19 tests / 89 assertions. New Ruby files pass RuboCop.
All 18 new/rewritten Swift source, package and test files pass syntax parsing;
plist/entitlements and JSON were validated. These checks do not compile Swift. The manual macOS mobile workflow has been extended to execute
the new Swift core tests before the simulator build; it has not been dispatched.
