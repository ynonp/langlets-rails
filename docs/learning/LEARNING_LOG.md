# Learning Log

## Covered flows
| Date | Flow | Key files | Score | Last commit studied | Lesson |
|------|------|-----------|-------|---------------------|--------|
| 2026-10-26 | Daily Langlets personalized recommendation (day 6+) | `app/jobs/send_daily_challenges_job.rb`, `app/jobs/prepare_daily_challenge_recommendation_job.rb`, `app/models/daily_challenge.rb`, `app/services/daily_video_recommendation.rb` | pending | 4d6b564 (flow last changed in 5b8c96a) | [lesson](lessons/2026-10-26-daily-langlets-recommendation.html) |

## Weak spots
- 

## Ideas for future lessons
- Video import flow (`Imports::Create`, `VideoPreflight`, `guest_started` mode)
- Starter challenge enrollment (`StarterChallenge.enroll!`, timezone scheduling)
- Notification delivery (`DeliverNotificationJob`, push/email)
- Vocabulary spaced reviews (commit 0bbbaaa)
- Pipeline `/recommend-video` grounding checks (`pipeline/src/videoRecommendation.ts`)

## Lesson notes
### 2026-10-26 — Daily Langlets personalized recommendation
- Summary: Scheduler → today's row → leased preparation job → Gemini pick → admin-owned guest_started import → ready → notify. Production delivery paused since 5b8c96a.
- Key concepts: row-lock + lease state machine, retry/attempt counting, delivery kill switch, no backfill.
- Quiz misses: pending
