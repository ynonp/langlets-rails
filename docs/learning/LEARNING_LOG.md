# Learning Log

## Covered flows
| Date | Flow | Key files | Score | Last commit studied | Lesson |
|------|------|-----------|-------|---------------------|--------|
| 2026-10-23 | Daily Langlets: scheduler tick → recommendation → notification | `app/jobs/send_daily_challenges_job.rb`, `app/models/daily_challenge.rb`, `app/jobs/prepare_daily_challenge_recommendation_job.rb`, `app/jobs/deliver_notification_job.rb` | pending | 4d6b564 | [lesson](lessons/2026-10-23-daily-langlets-delivery.html) |

## Weak spots
- (none yet)

## Ideas for future lessons
- Course import pipeline: `Imports::Create` → pipeline callback → published course
- Spaced vocabulary reviews (`ReviewLessonBuilder`, `PhraseTokenUser` schedule; commit 0bbbaaa)
- Notifications subsystem end to end (`Notifications::Deliver`, `Push::Notifier`)
- Subscriptions / `ExpireSubscriptionsJob`

## Lesson notes
### 2026-10-23 — Daily Langlets delivery
- Summary: Recurring job creates today's row, prepares an AI-recommended video (state machine pending→searching→importing→ready), notify! gates on unlocked?, DeliverNotificationJob sends email/push. Production delivery is paused via `config.x.daily_langlets_delivery_enabled`.
- Key concepts: row locks for idempotency, kill switch checked in three places, `sent_at` = attempted, outage rule (send only latest).
- Quiz misses: pending
