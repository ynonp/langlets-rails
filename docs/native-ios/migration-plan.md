# Swift iOS migration

## Objective and boundaries

Replace the iOS Hotwire learner experience with SwiftUI and a versioned Rails JSON API. Preserve the bundle ID, share extension, account data, channel visibility, import pricing and Android/web routes. Administrative operations and public marketing remain web surfaces. No production deployment or store release is part of implementation.

Native navigation, forms, exercises, transcript, audio, persistence and accessibility belong to Swift. YouTube/TikTok are provider embeds, isolated inside a media component; their watch pages are not AVPlayer resources. Do not promise offline provider video. Downloaded transcripts, exercises and platform pronunciation audio must work without connectivity. See official [YouTube iOS embedding](https://developers.google.com/youtube/v3/guides/ios_youtube_helper) and [TikTok player](https://developers.tiktok.com/doc/embed-player/).

## Screen and functionality inventory

| Existing entry | Swift destination and behavior | Offline behavior |
|---|---|---|
| onboarding/welcome, beta | Welcome, beta explanation, sign-in/create account | Bundled copy |
| onboarding/language, daily_challenge | Target languages, delivery channels, local reminder time/timezone; current quest and completion | Cached settings/quest; writes queued where safe |
| onboarding/video, try | Video URL entry and preview | Save draft; import requires connection |
| users/sign_in, sign_up/check_email, confirmations, passwords | Native credential forms, email confirmation/resend/recovery, Apple/Google and browser GitHub authentication | Existing account can open cached content; authentication requires connection |
| app home | Continue, latest imports, daily vocabulary, playlists, entitlement/streak | Cached dashboard, locally completed state |
| app/library, started_courses | Search, language/status filters, imports and playlists, pagination | Search downloaded data; indicate partial offline catalog |
| app/import_requests/new | URL, preview, explicit import, pending/failed/ready state | Persistent draft; never claim import submitted offline |
| courses/:slug | Course, lessons/progress, enroll, translate, share/unshare, playlist membership, reset/delete | Downloaded course; destructive/shared operations online |
| courses/:slug/full-player | Native transcript, translations, word selection/save, seeking, karaoke, sentence pause, text-only | Transcript/TTS; provider video explicitly online |
| courses/:course/lessons/:lesson | Full-screen lesson, activity navigation, skip, progress, close/resume | Downloaded activity bundle and durable progress outbox |
| ReadTranslated | Translation-first reading | Full |
| WatchVideo | Bounded provider playback plus interactive transcript | Transcript reading; video requires network |
| Flashcard, WriteMissingWord | Contextual cloze, choices/typing/hint, explicit next | Full text and downloaded pronunciation |
| MatchPhrases, MatchTokens | Phrase/token translation matching, feedback and paging | Full |
| WordOrder, SortPhrases | Sentence construction and chronological ordering | Full |
| LanguageAlignment, TokensChain | Token translation alignment and chained matching | Full |
| Listen | Timed listening with missing-token choices | Downloaded TTS alternative; provider audio online |
| Speak | Native microphone/speech recognition, model audio, retry/skip | On-device recognition when available; typing/skip otherwise |
| FindAnswer | Stored questions, answer-token selection | Full |
| lesson/review finish | Completion, progress/XP, next lesson/continue | Local completion immediately, sync later |
| app/vocabulary | Search/language/paused, context detail, pronunciation, pause/resume, delete/undo, add custom span/edit translation | Cached list and durable edits |
| review_lessons | Account/language-scoped prepared review; same native exercise engine | Download prepared reviews before travel |
| playlists, course_playlists | List, detail, search, create, add/remove, delete confirmation | Cached browsing; writes online |
| notifications | Read/unread history, mark read/all, typed deep links | Cached history; reads queued |
| profile, preferences | Native language (en/he/es), theme, notifications, account/sign-out/delete | Cached preferences; account changes online |
| app/pro, success | Beta/Pro/free entitlement; Discord contact; historical subscription management | Cached status, refresh before protected actions |
| invitations, channel_invitation token | Pending invitations, accept/decline | Cached list; membership changes online |
| settings/connections | Authorized clients and revoke | Online |
| privacy, terms, support | Native legal/support entry points to canonical documents | Bundled navigation; documents require network |
| APNs, custom URL scheme, share extension | Native route handling on cold/warm launch, installation registration, import token bootstrap | Defer routing until account available |

## Implementation sequence

1. Inventory architecture/schema/controllers/activity models and native lifecycle; verify both databases.
2. Add isolated `/api/v1/native` contract. Reuse domain services and authorization. Define consistent errors, bounded collections, language context, session lifecycle and least-privilege extension tokens. Keep existing API consumers compatible.
3. Add download bundles and idempotent mutation receipts. Serialize normalized, explicit fields (never ActiveRecord dumps). Scope every course/lesson/token/playlist access. Server computes XP; replay cannot award twice. Reject conflicting reuse of an operation UUID.
4. Implement native networking/Keychain, account-isolated disk persistence, durable outbox with retry/blocked states and reachability/foreground sync. Render cache before refresh. Sign-out cancels work and wipes private cache.
5. Implement four SwiftUI tabs, navigation/deep links, authentication and account/settings screens, course/download/playlist/import/vocabulary flows.
6. Implement shared native lesson/exercise and transcript engine, pronunciation audio, media-only embeds, speech, progress and completion.
7. Integrate share extension/APNs; localize en/es/he and RTL; expose download removal, sync status, error recovery and accessibility labels.
8. Verify Rails authorization/replay/contract tests and existing consumer regression tests; compile/test on macOS, then device airplane-mode/relaunch/account-switch/playback/VoiceOver checks. Update architecture and API documentation with actual coverage and limitations.

## Data and sync contract

- Local storage is partitioned by account ID and protected by iOS file protection; credentials use Keychain. Downloaded lessons are explicit durable files, not URLCache entries. Generated audio uses stable asset IDs.
- Each queued mutation carries a UUID and immutable JSON payload. Rails records UUID + SHA-256 payload + result atomically under the account lock. Replays return the result; changed payloads return 409. Completion checks current authorization and never accepts client XP.
- Completion is monotonic; settings and vocabulary practice flags use explicit desired values, never toggles. Server changes win on refresh after local pending overlays. 401 retains the outbox for reauthentication; 403/404/409/422 become visible conflicts rather than retry loops. Transport/5xx errors retry later.
- Imports/sharing/deletion/account changes require online confirmation. Imported course readiness remains server-owned. Private course downloads receive a finite offline access lease; revalidation can remove revoked downloads. Saved vocabulary remains available independently of course entitlement.
- Full bounded snapshots replace collection pages; absence from one page is not a deletion. Explicit detail 404/revocation removes only that entity. Catalog pagination must remain usable beyond the first page.

## Release acceptance

No Rails learner HTML in app navigation. Every inventory row either has tested native coverage or is explicitly listed as incomplete in the implementation status; do not call the migration finished while gaps remain. Existing web/Android/share API tests pass. Verify loss of network before/after a write, ambiguous timeout replay, app termination, user switch, revoked access, expired token, partial audio download, large type, Hebrew and long transcripts. Xcode compilation and real-device provider playback are release gates.
