# Learning Log

## Covered flows
| Date | Flow | Key files | Score | Last commit studied | Lesson |
|------|------|-----------|-------|---------------------|--------|
| 2026-10-25 | Daily Langlets recommendation & delivery | `app/jobs/send_daily_challenges_job.rb`, `app/jobs/prepare_daily_challenge_recommendation_job.rb`, `app/services/daily_video_recommendation.rb`, `app/models/daily_challenge.rb`, `app/jobs/deliver_notification_job.rb` | pending | `4d6b564` | [lesson](lessons/2026-10-25-daily-langlets-recommendation.html) |

## Weak spots
- (none yet)

## Ideas for future lessons
- Starter challenge enrollment (`StarterChallenge.enroll!`) and the first five curated quests
- Imports::Create / VideoPreflight: how a YouTube URL becomes an ImportRequest
- The pipeline (`pipeline/src/videoRecommendation.ts`): the other side of `recommend_video`
- Notifications.deliver and the email/push channels
- Spaced vocabulary reviews (commit 0bbbaaa)

## Lesson notes
### 2026-10-25 — Daily Langlets recommendation & delivery
- Summary: scheduler tick -> ensure today's row -> prepare job (lease, search, import) -> notify! -> DeliverNotificationJob. Production delivery is paused by `config.x.daily_langlets_delivery_enabled = false` (since 2026-10-17).
- Key concepts: prepare-before-notify, `with_lock` + returned symbol, DB lease (`SEARCH_LEASE`), `PREPARATION_LEAD`, skip-stale-days, kill switch.
- Quiz misses: pending
