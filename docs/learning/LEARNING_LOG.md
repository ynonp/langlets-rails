# Learning Log

## Covered flows
| Date | Flow | Key files | Score | Last commit studied |
|------|------|-----------|-------|---------------------|
| 2026-10-22 | Daily Langlets personalized recommendation | `send_daily_challenges_job.rb`, `prepare_daily_challenge_recommendation_job.rb`, `daily_video_recommendation.rb`, `daily_challenge.rb`, `starter_challenge.rb` | pending (quiz unanswered) | 4d6b564 |

## Weak spots
- None logged yet.

## Ideas for future lessons
- Video import: `Imports::Create` and the guest_started preparation mode
- Pipeline `/recommend-video` side (`pipeline/src/videoRecommendation.ts`, grounding checks)
- Notification delivery (`DeliverNotificationJob`, APNs)
- Spaced vocabulary reviews (commit 0bbbaaa)
- StarterChallenge enrollment and timezone scheduling

## Lesson notes
### 2026-10-22 — Daily Langlets personalized recommendation
- Summary: scheduler tick -> ensure today's row -> locked claim -> Gemini via pipeline -> admin-owned guest import -> ready -> notify. Full lesson: `docs/learning/2026-10-22-daily-langlets-recommendation.md`.
- Key concepts: row lock + time lease, self-healing scheduler, local-timezone day math, delivery pause switch.
- Quiz misses: awaiting answers.
