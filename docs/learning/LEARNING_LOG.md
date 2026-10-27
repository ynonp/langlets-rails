# Learning Log

## Covered flows
| Date | Flow | Key files | Score | Last commit studied | Lesson |
|------|------|-----------|-------|---------------------|--------|
| 2026-10-27 | Daily Langlets: scheduler → Gemini pick → course import → notify | `app/jobs/send_daily_challenges_job.rb`, `app/jobs/prepare_daily_challenge_recommendation_job.rb`, `app/models/daily_challenge.rb`, `app/services/daily_video_recommendation.rb` | pending | 8b4ac8e (flow last touched in 5b8c96a) | [lesson](lessons/2026-10-27-daily-langlets-recommendation.html) |

## Weak spots
- (none yet)

## Ideas for future lessons
- Video import pipeline: `Imports::Create` → pipeline → published Course (the other half of Daily Langlets)
- Starter challenge enrollment (`StarterChallenge.enroll!`, days 1–5 curated quests)
- Notification delivery: `Notifications.deliver` → `DeliverNotificationJob` → email / APNs push
- Spaced vocabulary reviews (commit 0bbbaaa)

## Lesson notes
### 2026-10-27 — Daily Langlets recommendation flow
- Summary: 5-minute scheduler creates today's row, a lease-guarded job asks Gemini for a validated YouTube pick, imports it as admin, and notifies only when the course is ready. Production delivery is paused (5b8c96a).
- Key concepts: `with_lock` state machine, SEARCH_LEASE, PREPARATION_LEAD, idempotent `find_or_create_by!`, `unlocked?` gating.
- Quiz misses: pending
