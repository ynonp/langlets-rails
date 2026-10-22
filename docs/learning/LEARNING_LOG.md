# Learning Log

## Covered flows
| Date | Flow | Key files | Score | Last commit studied | Lesson |
|------|------|-----------|-------|---------------------|--------|
| 2026-10-22 | Daily Langlets recommendation pipeline | `app/jobs/send_daily_challenges_job.rb`, `app/jobs/prepare_daily_challenge_recommendation_job.rb`, `app/models/daily_challenge.rb`, `app/services/daily_video_recommendation.rb` | pending | 4d6b564 | [lesson](lessons/2026-10-22-daily-langlets-recommendation.html) |

## Weak spots
- 

## Ideas for future lessons
- Spaced vocabulary reviews and familiarity controls (commit 0bbbaaa)
- Import request pipeline: `Imports::Create` through `PipelineClient.run` and `PipelineCallbacksController` (HMAC callbacks)
- Native auth handoff on Android (`NativeAuthHandoff`)
- Apple subscription notifications (`/apple/notifications`)

## Lesson notes
### 2026-10-22 — Daily Langlets recommendation pipeline
- Summary: sweep job creates today's quest, a per-quest job claims it under lock, asks the pipeline (Gemini) for a verified video, imports it as a course, then `notify!` delivers (currently paused in production).
- Key concepts: `with_lock` claim + 10-minute lease, 3-attempt limit, `PREPARATION_LEAD`, outage skip policy, delivery pause flag.
- Quiz misses: pending
