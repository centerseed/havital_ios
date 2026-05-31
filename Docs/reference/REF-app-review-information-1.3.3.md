---
doc_id: REF-app-review-information-1.3.3
title: App Review Information 1.3.3
type: REFERENCE
ontology_entity: demo-reviewer-access-gate
status: current
version: "1.0"
date: 2026-05-18
supersedes: null
---

# App Review Information 1.3.3

## Apple App Review Notes

Paceriz is a running training app that generates adaptive weekly plans, workout guidance, performance insights, and readiness feedback for runners.

To review the app with prepared sample data, please use the reviewer demo access flow:

1. Launch the app and stay on the login screen.
2. Long press the Paceriz logo for 5 seconds.
3. The reviewer access sheet will appear.
4. Enter this reviewer passcode: `<REVIEWER_PASSCODE>`
5. Tap Activate. The app will sign in to the Apple Review demo account automatically.

The demo account is preconfigured with an active training plan, weekly schedule, workout history, monthly training statistics, personal best records, readiness data, and subscription access for review.

Suggested review path:

1. Open the Training tab to view the current weekly schedule and training plan.
2. Open the Training Calendar and Monthly Stats to review monthly mileage and pace summaries.
3. Open the Performance tab to review readiness, personal bests, and training metrics.
4. Open Messages to review in-app announcements.
5. Open Profile to review account and language settings.

HealthKit, Apple Watch, Garmin, and Strava permissions are optional for review. If the reviewer declines permissions, the demo account still contains prepared sample data and the main app flows remain available.

The app supports Traditional Chinese, English, and Japanese. The login screen follows the device language by default, and the language can also be changed before sign-in. The selected app language is preserved after demo sign-in.

No real purchase is required for review. The demo account has reviewer subscription access configured so paid features can be evaluated without completing an App Store transaction.

## 中文備註

送審時不要把 reviewer passcode committed 到 repo。貼到 App Store Connect 前，將 `<REVIEWER_PASSCODE>` 換成當次有效 passcode。

Demo account UID:

`ZyIP5VxEapePp0P2erZx18WYGK92`

此帳號送審前必須確認：

- `users/{uid}.active_training_id` 存在
- `users/{uid}/plan_overviews_v2/{active_training_id}` 存在
- `users/{uid}/weekly_plans_v2/{active_training_id}_<current_week>` 可讀
- 訂閱狀態為 reviewer 可用狀態
