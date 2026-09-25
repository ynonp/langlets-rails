# Starter challenge video catalog

`config/starter_challenge_videos.yml` is the editable list used by the challenge
page. Every entry has a supported `language` code, `category` (`song`, `story`,
`tiktok`), title, canonical source URL, research URL, review date, and verification
level. Languages are `en`, `fr`, `es`, `he`, `de`, `el`, `sv`, `zh`, and `ar-JO`.
The Arabic choices should use Levantine Arabic rather than silently substituting
another dialect. Public source links do not grant rights to rehost video; the
app continues to use the existing provider players and import flow.

## Research status, 2026-09-24

There are 50 candidates: two YouTube songs and two stories per supported
language, plus 14 TikTok clips covering all nine languages. Greek, Levantine
Arabic, Swedish and Hebrew each have one TikTok candidate; the other languages
have two. Empty future language/category buckets show a choose-your-own-video
fallback. Do not fill missing buckets with unrelated languages or clips without
speech just to satisfy coverage.

All entries are `public_listing`: public metadata/listings establish the URL and
subject, but playback, spoken language, duration and end-to-end import have not
been confirmed for every clip. Supadata metadata/transcript requests returned
HTTP 429 (plan quota exhausted) during research, and TikTok blocks direct crawler
access. TikTok research uses indexed public listings, whose metadata can be
stale. These are candidates for review, not a promise of successful import.

## Reviewing or replacing a candidate

1. Open the canonical URL and watch it: check availability, spoken language,
   intelligible speech, short duration and suitability for a new learner.
2. For songs, prefer the artist/publisher; for stories, prefer short narrated
   stories. For TikTok, use a single clip URL, never a profile, hashtag or sound.
3. Use the existing import preview to check provider metadata and detected
   language. Run a full import when intentionally testing the paid pipeline.
4. Replace unavailable or unsuitable clips, keep the research URL/date current,
   and record the actual verification performed. Do not label listing-only
   research as a successful import.
5. Run `./bin/rails test test/services/starter_challenge_catalog_test.rb`.

The catalog is read locally and filtered by the user's selected languages. It
never calls Supadata or creates courses while displaying recommendations.
