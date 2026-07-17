# Langlets — iOS App Spec

Turn native content (YouTube videos) into language practice.

## Concept
Users bring their own native content: share a YouTube video into the app (or add one in-app), the pipeline converts it into a Langlets course (video → N lessons), and the user practices it exactly like existing Langlets courses.

## Core flows

### 1. Share from YouTube (share extension) — screen 05
- User taps Share in YouTube (or any app sharing a YouTube URL) → picks **Turn** in the iOS share sheet.
- Extension resolves the URL, shows video title/thumbnail, and confirms: "Added to your queue — importing now. We'll ping you when it's ready."
- Video is added to the processing queue with the user's default language pair (video language auto-detected; translation language = user's learning setting). No further input required — one tap.
- Costs 1 credit (see Credits). If balance is 0, extension deep-links into the app's buy-credits sheet.

### 2. Add Video in-app — screen 04
- Entry: green **+** button in the tab bar (all tabs).
- Bottom sheet with two modes (segmented control):
  - **Paste link**: URL field, validates YouTube URL (green check), fetches preview (thumbnail, title, duration).
  - **Search YouTube**: keyword search, pick a result.
- Settings rows: **Video language** (auto-detected, editable) and **Translate to**.
- CTA: **"Import · 1 credit"**. Sub-copy: "Usually ready in ~5 min — we'll send you a push."
- On import: deduct 1 credit, enqueue, dismiss to Queue tab.

### 3. Processing queue — screen 03
- Lists the user's imports in progress. Per item: thumbnail, title, progress bar + simple percent ("Importing · 68%").
- States: **Importing** (percent), **Queued** (dashed card, "Queued — up next"), **Ready** (green check, "Ready — waiting on Home").
- Footer copy: imports take a few minutes; app can be closed; push sent per finished item.
- Tab bar Queue icon shows a badge with the count of active imports.

### 4. Push notification + landing — screens 07 → 01
- When an import finishes: push notification — title "Your course is ready!", body "“{video title}” is now {N} lessons. Tap to start practicing."
- Tapping the push opens **Home** with the new course as a hero card ("JUST IMPORTED" badge) and a **Start Course** button → opens the standard Langlets course/lesson experience.

## Screens

### Home (tab 1) — screen 01
- Header: Turn wordmark, credits pill (balance), avatar.
- Greeting ("Ready to practice, {name}?").
- **Just imported** hero card: thumbnail, title, "Spanish → English · 11 lessons", Start Course.
- **Keep it going**: list of in-progress courses (thumb, title, "Lesson X of Y", progress bar). Includes content the user imported AND content started from the Library.
- Scope: only *this user's* content (imported by them or started by them).

### Library (tab 2) — screen 02
- All content imported by **any** Langlets user (community catalog).
- Search field (titles/channels/songs; also accepts a pasted link).
- Filter chips: All / Music / Shows / Kids / News (category taxonomy from pipeline metadata).
- 2-column grid of cards: thumbnail, title, "{language} · {N} lessons", **+ Learn this** action (adds to the user's Home, no credit cost — content already imported).

### Queue (tab 3) — screen 03
As described in flow 3.

### Navigation
- Bottom tab bar: **Home / Library / Queue** + floating green **+** (Add Video) — visible on all three tabs.
- Queue tab badge = active import count.

## Credits & IAP — screen 06
- Importing a video runs AI processing → metered by **credits**.
- New users get **3 free credits**. Each video import = **1 credit**. Adding existing Library content = free.
- Credit balance shown on Home header and in the Add Video sheet ("2 credits left").
- When balance is 0 and user tries to import → **Out of credits** bottom sheet:
  - Packs (IAP consumables): 5 credits $2.99 · 15 credits $6.99 (highlighted "Most popular", $0.47/import) · 40 credits $14.99 ("Best value", $0.37/import).
  - CTA "Get 15 credits" (defaults to the highlighted pack); "Restore purchases" link.
- Backend must track balance server-side; extension and app share it.

## Backend integration (existing Langlets)
- **Import pipeline**: submit YouTube URL + (video language, translation language) → job with progress events (expose a simple percent) → produces a course of N lessons. Reuse as-is.
- **Practice**: courses/lessons/activities identical to Langlets web (bilingual phrase breakdowns, timestamps, AI activities, spaced repetition).
- **Catalog**: imported content is public → appears in every user's Library (dedupe imports by YouTube video ID + language pair; a duplicate import should return the existing course without charging a credit — confirm desired behavior).
- Languages supported: English, Hebrew, French, Spanish, Arabic.

## Notifications
- APNs push per finished import (and optionally per failed import).
- Tap → deep link to the new course on Home.

## Visual design (see mockups)
- Dark theme only. Background `#0A1521`, cards `#11202F` with `0.5px rgba(255,255,255,0.07)` borders, secondary text `#8FA0AE`.
- Accent emerald `#1DC77C` (buttons use dark green text `#052012`); pill-shaped CTAs, radius 16–20 cards — matches Langlets web.
- Type: SF Pro (system), friendly & encouraging copy tone.
- Sample language pair in mocks: Spanish → English.

## Edge cases to handle (not mocked)
- Failed import: notify + refund the credit; show error state in Queue with retry.
- Invalid / private / age-restricted / >X-min videos: reject at Add step with clear message, no charge.
- Offline: queue the submission, send when back online.
- Share extension when signed out → open app to sign-in.
