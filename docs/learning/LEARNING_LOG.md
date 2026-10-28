# Learning Log

## Covered flows
| Date | Flow | Key files | Score | Last commit studied | Lesson |
|------|------|-----------|-------|---------------------|--------|
| 2026-10-28 | Daily Langlets: personalized video recommendation → notification delivery (day 6+) | `app/jobs/send_daily_challenges_job.rb`, `app/models/daily_challenge.rb`, `app/jobs/prepare_daily_challenge_recommendation_job.rb`, `app/services/daily_video_recommendation.rb`, `app/jobs/deliver_notification_job.rb` | pending | `5b8c96a` (flow files); repo HEAD `8b4ac8e` | [lesson](lessons/2026-10-28-daily-langlets-recommendation.html) |

## Weak spots
- (none yet)

## Ideas for future lessons
- Importing a video into a course (`Imports::Create` → pipeline), the other half of Daily Langlets
- `StarterChallenge.enroll!` and timezone-aware scheduling for days 1–5
- Review lessons and copied-word translation skipping (`ReviewLessonBuilder`, commit `8b4ac8e`)
- Notifications: `Notifications.deliver` → email/APNs push

## Lesson notes
### 2026-10-28 — Daily Langlets recommendation & delivery
- Summary: 5-min scheduler creates today's row, a leased/locked job asks Gemini for a video and imports it, then notify! → DeliverNotificationJob. Production delivery is paused via three guards.
- Key concepts: row locks + unique index for idempotency, lease (SEARCH_LEASE), state machine pending→searching→importing→ready/failed, skip-stale-days, pause flag `!= false`.
- Quiz misses: pending
