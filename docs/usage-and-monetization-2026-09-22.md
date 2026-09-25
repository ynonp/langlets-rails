# Usage, acquisition, and the path to paid Pro

Assessment: September 22, 2026, approximately 19:38–19:44 UTC.

Recommendation: begin a small, explicitly paid Pro pilot within the next one to two weeks. First validate that new customers will pay and return; defer broad paid acquisition until renewal and contribution margin are observable. Current evidence supports interest in trying the product, but not a repeatable subscription business yet.

## Evidence and definitions

Read production through Kamal's Rails runner using PostgreSQL read-only transactions. Queried PostHog project 622796 through its API, using production credentials without displaying their values. No production records, offers, grants, dashboards, or settings were changed.

The database contains 74 accounts, including administrator #1. Accounts #398 and #430 together account for 709 of 805 non-admin activity-completion records (88%), 482 of 544 lesson marks (89%), and 255 of 280 saved-word records (91%). Both have unusually large credit balances. Their identities as customers, founder accounts, or testers are unconfirmed. Report them separately rather than silently treating them as customers or deleting them from the evidence.

For this assessment, a recorded learning action is an activity-completion row, activity-log row, or saved-word row. An active learner has at least one such action in the period; a returning learner has actions on multiple UTC calendar dates. These are imperfect proxies: completion rows record first completions, saved words can be removed, and repeat playback or reading need not create a row. LessonUser rows were excluded from the primary action measure because users can manually mark lessons done. Account deletion and historical instrumentation changes also limit lifetime comparisons. Counts are snapshots from several queries during live usage, not one frozen cross-system snapshot.

| Measure | Excluding admin | Also excluding #398 and #430 |
|---|---:|---:|
| Accounts | 73 | 71 |
| Ever recorded a learning action | 24 | 22 |
| Active in trailing 28 days | 18 | 16 |
| Active in trailing 7 days | 5 | 3 |

Only seven non-admin accounts have recorded actions on two or more dates; five have actions on at least three dates. These figures include #398 and #430. Account #770 supplies a useful additional signal: seven learning dates in the last 28 days, 12 import requests, and 16 currently saved words. It already has a free Pro grant, so its usage is not evidence of willingness to pay.

## The clearest acquisition cohort

The week September 7–13 produced 25 signups, including 12 on September 8. The following week produced five signups. September 7–13 accounts have the following observed outcomes as of this assessment:

| Outcome | Accounts | Share of 25 signups |
|---|---:|---:|
| Requested at least one import | 19 | 76% |
| Has at least one ready import | 17 | 68% |
| Completed at least one activity | 11 | 44% |
| Has a lesson activity log | 6 | 24% |
| Recorded learning actions on multiple dates | 1 | 4% |

These are account-level outcomes, not an event-ordered funnel. They do not establish which action preceded another. The return measure is an observed multi-date count, not formal day-seven retention; accounts have different ages and the whole cohort has not completed a 14-day observation window.

All 11 activity completers completed ReadTranslatedActivity. Only four completed flashcards and four completed phrase matching; those groups overlap. The first useful experience appears to be stronger than deeper practice and habit formation. This suggests testing an easier transition from understanding a clip into a second learning session before building more activity types.

The same cohort has 21 ready and nine failed import-request rows. Across the last 28 days, excluding admin and the two flagged accounts, there are 41 ready and 14 failed request rows: 25% are currently failed. This is a current-state request ratio, not a first-attempt failure rate or a percentage of users who failed. Retries can alter rows and their timestamps. Successful rows have median updated_at minus created_at of 71 seconds and a 90th percentile of 195 seconds. These are timing proxies, not measured time-to-ready. Five of the 14 failure messages mention language; the other nine need individual categorization before choosing a fix.

English and French each have six activity completers outside the three excluded accounts; English has 57 activity completions versus French's 11. Arabic's dominant lesson volume largely comes from the flagged accounts. English is a reasonable segment to investigate, not a proven market winner. Native-language preferences are mostly absent, so Hebrew-to-English positioning is a hypothesis to validate with conversations.

## What PostHog currently tells us

At query time, events cover only September 22, 17:09–19:39 UTC: approximately 2.5 hours. There are 229 events across 202 distinct IDs, including 218 page views across 200 IDs and two analytics-verification events.

Of the 218 page views, 158 are web login-page requests, each with a different anonymous ID. There are three authenticated identities: admin #1, flagged account #398, and account #796. The latter contributes 15 events, including two activity completions, and is using the native app. No signup or import-request events were present in this sample.

Do not describe this as 200 interested visitors. Anonymous identifiers are session-scoped; cookie-less requests can each create a new ID. Server-side page views can include crawlers. The pattern is consistent with automated or cookie-less requests, but available properties cannot establish bot identity. Nor can this sample establish a signup conversion rate or explain the earlier acquisition spike.

Instrumentation gaps:

- Guest IDs switch to user IDs on login/signup without an explicit merge in the reviewed capture code. Cross-authentication funnels can break.
- UTM source is stored in the Rails session and on Prospect, not on ordinary User signups. Page-view URLs omit queries, and events do not generally carry acquisition fields. Referrer/source attribution is therefore largely unavailable for ordinary acquisition.
- Admin routes are excluded, but admin/test users browsing ordinary product pages are still counted.
- Activity and lesson completion events mostly report first completions. Guest practice does not emit the same completion events, and repeated practice can be missed.
- Import request events exist, but the inspected instrumentation does not provide a complete ready/failed/first-play funnel or current purchase-intent and checkout funnel.

Use PostHog's [query API documentation](https://posthog.com/docs/api/queries) for the reporting implementation. Add acquisition and lifecycle fields deliberately, retaining the existing protection against recording email, bearer tokens, and video content.

## Do we have an acquisition strategy?

There is acquisition infrastructure and an implicit strategy: expose useful video lessons, let people try, then invite them to create their own lessons. The product supports shared courses, guest video selection, email capture, social authentication, native apps, and free Pro invitations.

The evidence does not establish a repeatable acquisition channel. The signup burst suggests a discrete distribution event, but its cause cannot be recovered from these records. Confirm what was published around September 8 before attributing it to Facebook, a newsletter, an app launch, or anything else.

The Prospect table contains just one lead, tagged `fb`, with no activation. The guest-evaluation table contains 34 records with ten claimed and nine consumed. These are separate flows, not stages that can be combined with all signups into a single funnel; evaluation rows are not necessarily unique people.

The current offer is also structurally disconnected from revenue: all three subscription rows are free console grants, paid purchase UI is removed, and both the prospect activation flow and manual Pro grant default to a 100-year entitlement. No paid subscription rows were found. This establishes no paid subscription evidence in this database, not proof that money was never collected elsewhere.

Keep promises already made to existing users. For future acquisition, replace indefinite free Pro with a clear bounded trial or the existing three-import allowance. Do not retrospectively expire grants as part of this analysis.

## Six-week operating plan

The thresholds below are proposed decision rules for a small experiment, not industry benchmarks or statistically reliable population estimates.

### Week 1: learn why people stop and make the funnel measurable

1. Confirm internal/test accounts and exclude them from customer reports. Persist campaign source on ordinary account creation and connect anonymous and authenticated identities. Separate guest and authenticated activation, repeat practice, and repeat viewing.
2. Track: attributable landing visit → first meaningful learning action → account creation → import ready → practice after import → return practice → offer viewed → checkout started → paid → renewed. Acquisition can occur before or after first practice, so keep distinct entry-flow funnels.
3. Interview five recent users who stopped and three who returned, if available. Observe one real session per person. Ask what they wanted to understand, where they stopped, what replaced Langlets, and what made them return. Include #770; do not assume the flagged power users represent the market.
4. Investigate failed imports and introduce reliable ready/failed timing metrics. Measure transcription, model, translation, storage, delivery, and support costs per successful imported minute, including retries and abandoned guest imports.
5. Choose one audience based on those conversations. A starting hypothesis is intermediate English learners who already watch short videos and want to understand them without repeatedly interrupting playback. Hebrew-speaking learners are a candidate if the founder can reach them reliably.

### Weeks 1–2: ask for real payment

Recruit 10–15 qualified new prospects who already learn from videos. Demonstrate one personally relevant clip and help them complete a first exercise. Offer a small founding Pro pilot at $10/month, with clear cancellation and precisely stated entitlements. Existing historical product pricing was $10/month or $100/year; use monthly first to observe renewals. This is a price test, not an established optimal price.

Aim for five genuinely paying customers who are not the founder or testers. Payment is stronger evidence than a survey answer. Do not revoke existing free grants to manufacture conversions. A payment path must work on the actual platforms these recruits use; the old Apple verification backend exists, but the purchase UI is disconnected and a complete current checkout path is not established by this review.

Offer the outcome: understand videos you already want to watch and remember useful language from them. Start with assisted onboarding using the existing import and practice product. Avoid building a separate tutoring or enterprise product for the pilot.

For future paid plans, define an import-minute allowance from observed costs before promising unlimited AI processing. A bounded processing allowance with repeated study of ready content is a candidate packaging change, not current implemented behavior. Explain what happens to imported content if Pro ends; the existing Pro-library model withdraws access on expiry. Let customers understand this before paying.

### Weeks 2–4: repeat one acquisition experiment

Use one relevant community or small creator/newsletter partnership with permission. Share three already-built short lessons each week under one clear language-learning promise. Each asset gets a unique campaign tag and sends people directly to the lesson. Let people experience value before requiring them to choose a video URL or wait for generation. Invite activated learners to bring their own clip.

Record founder time as well as cash spend. Judge the channel by returning learners and paying customers per asset, not visits or raw signups. Repeat the distribution action that generated September 8's spike only after its source is confirmed, and compare downstream behavior.

On the product side, focus on the next session: a clear next exercise, a small saved-word review, and an opt-in reminder with a specific reason to return. Measure whether users voluntarily continue; assisted sessions and reminder-driven sessions should be distinguishable.

### Weeks 4–6: decide whether to open sales more broadly

Seek an initial fresh cohort of at least 20 target users, with at least 12 reaching a meaningful first exercise and at least six returning to practice during days 7–13. Wait until everyone in the denominator has completed the observation window.

Alongside that, seek at least five actual paying pilot customers and at least four first-month renewals once due. Require recent successful imports to reach at least 95% over a stated sample of 20 or more valid requests, and quantify service latency and costs. Small samples are directional; repeat them before increasing spend substantially.

If people pay but fail to return, improve recurring value and onboarding before expanding. If people return but will not pay, test the paid offer and audience. If people neither return nor pay, narrow or change the problem being solved rather than adding more general features. Do not let a calendar date override these observations.

## Money and economics

At $10/month, five payers mean $50 gross monthly recurring revenue, 100 mean $1,000, and 1,000 mean $10,000. These are arithmetic scenarios, not forecasts, and precede payment/platform fees, taxes, refunds, processing, hosting, and support. The user's desired income target and available acquisition budget are not yet known.

Measure monthly contribution per paying customer as net subscription receipts minus variable processing, delivery, and service costs. A provisional goal is at least 70% contribution margin before fixed costs and founder compensation. Report cash acquisition cost and founder time separately. Do not buy acquisition at scale until renewals are visible; a provisional paid-channel gate is acquisition cost recoverable within three months of observed contribution, adjusted for churn.

Illustrative arithmetic only: 25 targeted signups/week × 4 weeks × 60% activation × 20% activated-to-paid conversion = 12 new payers/month, or $120 in added gross MRR before churn. At 10% monthly churn, that inflow would approach roughly 120 subscribers, or $1,200 gross MRR, in a simplified steady-state model. None of those assumed conversion or churn rates is established by current data. The business ultimately needs more qualified reach, stronger conversion, better retention, a higher price, or a combination.

The next milestone is five customers paying for a repeatable learning benefit and choosing to renew. A polished public paywall can follow that evidence; the first honest payment test should begin much sooner.
