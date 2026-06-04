# Design Spec: Loading Context + Auto Goal Sheet + Sunday Push Notification

Date: 2026-06-04  
Scope: iOS app (Havital / Paceriz)  
Status: Approved

---

## Overview

Three user-facing improvements to the weekly plan generation flow:

1. **Contextual Loading Screen** — While generating a weekly plan, show the user the actual inputs the algorithm uses (VDOT, last week volume, training phase), making the loading wait feel informative rather than empty.
2. **Auto-show Goal Sheet** — After a plan is successfully generated, automatically present the "本週目標" (WeekTargetDetailViewV2) sheet so users immediately understand what Paceriz designed for them.
3. **Sunday Push Notification** — Conditionally schedule a local notification at 20:00 on Sundays to remind users to view their weekly review, only when they had a training day scheduled and actually ran.

---

## Feature 1: Contextual Loading Screen

### Goal
Replace the three static loading messages with dynamic, data-driven Pipeline Narrative messages that show the user what the algorithm is considering.

### Data Source
Data is collected **before** calling `repository.generateWeeklyPlan`, from already-available iOS state:

| Field | Source in iOS |
|---|---|
| `weekNumber` | `loader.selectedWeek` |
| `totalWeeks` | `loader.planOverview?.totalWeeks` |
| `vdot` | `loader.weeklyPlan?.vdot ?? loader.weeklyPlan?.currentVdot` |
| `lastWeekVolumeKm` | `loader.weeklyPlan?.totalDistance` (previous week's plan volume) |
| `phaseName` | Derived from `loader.planOverview?.stages` + `selectedWeek` → zh-TW name |
| `isRecoveryWeek` | Derived from stage info in planOverview |

When data is unavailable (e.g. generating Week 1 for the first time), each field degrades gracefully to a non-data fallback message.

### New Struct: `PlanGenerationContext`

```swift
struct PlanGenerationContext {
    let weekNumber: Int
    let totalWeeks: Int?
    let vdot: Double?
    let lastWeekVolumeKm: Double?
    let phaseName: String?        // already localized, e.g. "基礎期" / "Base Phase"
    let phaseWeek: Int?           // current week within phase
    let phaseTotalWeeks: Int?     // total weeks in current phase
}
```

No computed logic in this struct — caller is responsible for deriving values from loader state.

### Loading Message Format (3 steps)

| Step | Has data | Fallback (no data) |
|------|---|---|
| Step 1 (0–4s) | `"分析體能基準 · VDOT {vdot} · 上週跑量 {x} km"` | `"分析你的訓練記錄中"` |
| Step 2 (4–8s) | `"計算最適跑量 · {phaseName}第 {N} 週 / 共 {M} 週"` | `"根據訓練歷史計算本週跑量"` |
| Step 3 (8–12s) | `"生成第 {weekNumber} 週個人化課表 · 最佳化強度分配中"` | `"生成個人化訓練課表中"` |

All message variants must be covered by i18n keys in all three locales (zh-TW, ja, en).

### API Changes

`LoadingAnimationView.init` gains an optional `context: PlanGenerationContext?` parameter:

```swift
init(type: LoadingType = .generatePlan, context: PlanGenerationContext? = nil, totalDuration: Double = 25)
```

When `context != nil` and `type == .generatePlan`, the `messages` property is replaced by dynamically-constructed strings using context data. All existing call sites remain valid (no context → static fallback messages, same as today).

### Trigger Point

In `WeeklyPlanGenerator.generateCurrentWeekPlan()` and `generateWeeklyPlanDirectly()`:

```
1. Build PlanGenerationContext from loader state
2. setLoadingAnimation(true, context: context)   ← new signature
3. call repository.generateWeeklyPlan(...)
4. wait min 10s
5. setLoadingAnimation(false)
```

`setLoadingAnimation` closure signature changes to `(Bool, PlanGenerationContext?) -> Void`. The context is forwarded to the `TrainingPlanV2View` which passes it into `LoadingAnimationView`.

---

## Feature 2: Auto-show 本週目標 Sheet After Generation

### Goal
After a weekly plan is successfully generated, automatically present the existing `WeekTargetDetailViewV2` sheet (coachNote + purpose + designReason) so the user is immediately shown the week's rationale.

### ViewModel Change

Add to `TrainingPlanV2ViewModel`:

```swift
var shouldAutoShowWeekTarget: Bool = false
```

`WeeklyPlanGenerator` sets `shouldAutoShowWeekTarget = true` immediately after setting `loader.planStatus = .ready(plan)` for any **new** plan generation (not regeneration or re-load from cache).

### View Layer

In `TrainingPlanV2View`:

```swift
@State private var autoShowWeekTarget = false
```

Observation:

```swift
.onChange(of: viewModel.shouldAutoShowWeekTarget) { _, flag in
    guard flag else { return }
    viewModel.shouldAutoShowWeekTarget = false
    // Small delay so the main plan UI renders first
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        autoShowWeekTarget = true
    }
}
```

`WeekOverviewCardV2` receives a `Binding<Bool>` to trigger the sheet:

```swift
WeekOverviewCardV2(viewModel: viewModel, plan: weeklyPlan, autoShowTarget: $autoShowWeekTarget)
```

Inside `WeekOverviewCardV2`, the existing `@State private var showWeekTargetDetail` is replaced by:

```swift
@Binding var autoShowTarget: Bool
```

The sheet triggers on `autoShowTarget` OR the existing button tap (both set the same displayed state). All existing call sites that don't need auto-show pass `autoShowTarget: .constant(false)`.

---

## Feature 3: Sunday Push Notification (Conditional Local Notification)

### Goal
On Sundays, if the user had a scheduled training day AND recorded an actual workout, schedule a local push notification at 20:00 reminding them to view their weekly review.

### New Service: `WeeklySundayReminderService`

Location: `Havital/Features/TrainingPlanV2/Domain/WeeklySundayReminderService.swift`

```swift
protocol WeeklySundayReminderService {
    func checkAndScheduleIfNeeded(weeklyPlan: WeeklyPlanV2, todayWorkoutExists: Bool)
}
```

Logic:

```
1. Guard: today is Sunday (Calendar.current.component(.weekday) == 1)
2. Guard: current week plan's Sunday day has type != .rest (has training scheduled)
3. Guard: todayWorkoutExists == true (user actually ran today)
4. Remove any pending notification with identifier "weekly_sunday_reminder"
5. Schedule UNCalendarNotificationTrigger for 20:00 today
6. Content: title = L10n for "notification.sunday_reminder.title"
            body  = L10n for "notification.sunday_reminder.body"
```

### Notification Content (i18n)

| Locale | Title | Body |
|---|---|---|
| zh-TW | `本週訓練完成了 💪` | `今天的訓練成果已準備好，來看看 Paceriz 怎麼評估你這週的表現` |
| ja | `今週のトレーニング完了 💪` | `今日のトレーニング結果が準備できました。Pacerizによる週間評価をご確認ください` |
| en | `Week complete 💪` | `Your training results are ready. See how Paceriz evaluates your week` |

### Trigger Point

In `TrainingPlanV2View.task(id: scenePhase)`:

```swift
guard scenePhase == .active else { return }
// ... existing logic ...
if case .ready(let plan) = viewModel.loader.planStatus {
    let todayWorkoutsExist = viewModel.loader.currentWeekWorkouts.contains { 
        Calendar.current.isDateInToday($0.startDate) 
    }
    sundayReminderService.checkAndScheduleIfNeeded(
        weeklyPlan: plan,
        todayWorkoutExists: todayWorkoutsExist
    )
}
```

`WeeklySundayReminderService` is injected via `DependencyContainer`.

### Deduplication

Uses a fixed notification identifier `"weekly_sunday_reminder"`. Each call first removes the existing pending notification for this identifier before scheduling, so calling the service multiple times (each app-active on Sunday) is idempotent.

---

## Files to Create / Modify

### New Files
- `Havital/Features/TrainingPlanV2/Domain/WeeklySundayReminderService.swift`
- `Havital/Features/TrainingPlanV2/Domain/PlanGenerationContext.swift`

### Modified Files
- `Havital/Views/Common/LoadingAnimationView.swift` — add `context` parameter, dynamic message generation
- `Havital/Features/TrainingPlanV2/Presentation/ViewModels/WeeklyPlanGenerator.swift` — collect context, set `shouldAutoShowWeekTarget`, call new reminder service signature
- `Havital/Features/TrainingPlanV2/Presentation/ViewModels/TrainingPlanV2ViewModel.swift` — add `shouldAutoShowWeekTarget`, update `setLoadingAnimation` closure
- `Havital/Features/TrainingPlanV2/Presentation/Views/TrainingPlanV2View.swift` — `autoShowWeekTarget` state + onChange, pass into `WeekOverviewCardV2`
- `Havital/Features/TrainingPlanV2/Presentation/Views/Components/WeekOverviewCardV2.swift` — `autoShowTarget: Binding<Bool>` parameter, replace local state trigger
- `Havital/Core/DI/DependencyContainer.swift` — register `WeeklySundayReminderService`
- `Havital/Resources/*.lproj/Localizable.strings` — new i18n keys for loading messages + notification content
- `Havital/Utils/LocalizationKeys.swift` — new L10n keys

---

## Out of Scope
- Backend changes (all data is sourced from iOS-available state)
- Showing "live" pipeline decisions as the API computes them (not feasible without streaming API)
- Feature flags or A/B testing
- Notification scheduling when app has never been opened on Sunday (requires background fetch or server-side push, deferred)
