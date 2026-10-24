# Learning Log

## Covered flows
| Date | Flow | Key files | Score | Last commit studied | Lesson |
|------|------|-----------|-------|---------------------|--------|
| 2026-10-24 | Daily Langlets: from scheduler tick to push notification | `app/jobs/send_daily_challenges_job.rb`, `app/models/daily_challenge.rb`, `app/jobs/prepare_daily_challenge_recommendation_job.rb`, `app/services/daily_video_recommendation.rb`, `app/services/imports/create.rb`, `app/jobs/deliver_notification_job.rb` | pending | 4d6b564 | [lesson](lessons/2026-10-24-daily-langlets.html) |

## Weak spots
- 

## Ideas for future lessons
- Video import: `Imports::Create` end to end (preflight, pricing, dedupe, pipeline callback)
- Spaced vocabulary reviews (`PhraseTokenUser`, `ReviewLessonBuilder`, commit 0bbbaaa)
- Starter challenge enrollment (`StarterChallenge.enroll!`) and how reminder time zones work
- Notification delivery and push (`Notifications.deliver`, `Push::Notifier`)

## Lesson notes
### 2026-10-24 — Daily Langlets: from scheduler tick to push notification
- Summary: Every 5 minutes `SendDailyChallengesJob` creates today's `DailyChallenge`, prepares a Gemini-picked video 30 minutes ahead, imports it as a course, then notifies. Production delivery has been paused since 2026-10-17.
- Key concepts: `PREPARATION_LEAD`, `with_lock` leases, recommendation_state machine, `delivery_enabled?` pause flag, `prepared_daily_video` reuse.
- Quiz misses: pending
