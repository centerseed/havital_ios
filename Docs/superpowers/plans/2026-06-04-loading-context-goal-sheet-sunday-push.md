# Loading Context + Auto Goal Sheet + Sunday Push — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add contextual loading messages during plan generation (VDOT/volume/phase), auto-show the weekly goal sheet after generation, and schedule a conditional Sunday 8pm local notification when the user ran.

**Architecture:** Three independent changes that touch a shared data path: (1) `PlanGenerationContext` flows from `WeeklyPlanLoader` through `WeeklyPlanGenerator` into `LoadingAnimationView`; (2) a `shouldAutoShowWeekTarget` flag flows from generator → ViewModel → View → `WeekOverviewCardV2`; (3) `WeeklySundayReminderService` is called from `scenePhase.active` after the plan loads.

**Tech Stack:** Swift 5.9, SwiftUI `@Observable`, `UserNotifications` framework, existing `UNUserNotificationCenter` pattern from `SyncNotificationManager.swift`.

---

## File Map

| File | Change |
|---|---|
| `Havital/Utils/LocalizationKeys.swift` | Add `Training.LoadingAnimation` pipeline keys + `Training.Stage` enum + `L10n.Notification.SundayReminder` |
| `Havital/Resources/zh-Hant.lproj/Localizable.strings` | 12 new keys |
| `Havital/Resources/en.lproj/Localizable.strings` | 12 new keys |
| `Havital/Resources/ja.lproj/Localizable.strings` | 12 new keys |
| `Havital/Features/TrainingPlanV2/Domain/PlanGenerationContext.swift` | **NEW** struct with builder |
| `Havital/Views/Common/LoadingAnimationView.swift` | Add `context: PlanGenerationContext?` param |
| `Havital/Features/TrainingPlanV2/Presentation/ViewModels/TrainingPlanV2ViewModel.swift` | Add `loadingAnimationContext`, `shouldAutoShowWeekTarget`; update closure signatures |
| `Havital/Features/TrainingPlanV2/Presentation/ViewModels/WeeklyPlanGenerator.swift` | Build context before generation; set `shouldAutoShowWeekTarget` on success |
| `Havital/Features/TrainingPlanV2/Presentation/Views/TrainingPlanV2View.swift` | Thread context into sheet; add `autoShowWeekTarget` state + onChange; call reminder service |
| `Havital/Features/TrainingPlanV2/Presentation/Views/Components/WeekOverviewCardV2.swift` | Add `@Binding var autoShowTarget: Bool`; watch with `.onChange` |
| `Havital/Features/TrainingPlanV2/Domain/WeeklySundayReminderService.swift` | **NEW** local notification service |
| `Havital/Core/DI/AppDependencyBootstrap.swift` | Register `WeeklySundayReminderService` |
| `HavitalTests/TrainingPlanV2/PlanGenerationContextTests.swift` | **NEW** unit tests for builder + stage mapping |

---

## Task 1: Add i18n strings (all 3 locales + LocalizationKeys)

**Files:**
- Modify: `Havital/Utils/LocalizationKeys.swift`
- Modify: `Havital/Resources/zh-Hant.lproj/Localizable.strings`
- Modify: `Havital/Resources/en.lproj/Localizable.strings`
- Modify: `Havital/Resources/ja.lproj/Localizable.strings`

- [ ] **Step 1: Add keys to `LocalizationKeys.swift`**

Find the `enum LoadingAnimation` block (around line 530) and add pipeline keys after the existing `preparingCustomPlan` key. Then add a new `Stage` enum and a `Notification` enum at the top-level `L10n` scope.

In `LoadingAnimation`:
```swift
// Pipeline Narrative keys (Feature 1)
static let pipelineStep1WithData     = "training.loading.pipeline_step1_with_data"
static let pipelineStep1VdotOnly     = "training.loading.pipeline_step1_vdot_only"
static let pipelineStep1Fallback     = "training.loading.pipeline_step1_fallback"
static let pipelineStep2WithData     = "training.loading.pipeline_step2_with_data"
static let pipelineStep2Fallback     = "training.loading.pipeline_step2_fallback"
static let pipelineStep3WithWeek     = "training.loading.pipeline_step3_with_week"
static let pipelineStep3Fallback     = "training.loading.pipeline_step3_fallback"
```

After the existing `Training` enum, add a new `Stage` enum inside `Training`:
```swift
enum Stage {
    static let base       = "training.stage.base"
    static let build      = "training.stage.build"
    static let peak       = "training.stage.peak"
    static let taper      = "training.stage.taper"
    static let conversion = "training.stage.conversion"
    static let unknown    = "training.stage.unknown"
}
```

At top-level `L10n` enum (find the closing `}` of `L10n`), add before it:
```swift
enum Notification {
    enum SundayReminder {
        static let title = "notification.sunday_reminder.title"
        static let body  = "notification.sunday_reminder.body"
    }
}
```

- [ ] **Step 2: Add strings to zh-Hant Localizable.strings**

Find line ~333 (after `training.loading.preparing_review`) and add:
```
"training.loading.pipeline_step1_with_data" = "分析體能基準 · VDOT %@ · 上週跑量 %@ km";
"training.loading.pipeline_step1_vdot_only" = "分析體能基準 · VDOT %@";
"training.loading.pipeline_step1_fallback" = "分析你的訓練記錄中...";
"training.loading.pipeline_step2_with_data" = "計算最適跑量 · %@第 %d 週 / 共 %d 週";
"training.loading.pipeline_step2_fallback" = "根據訓練歷史計算本週跑量...";
"training.loading.pipeline_step3_with_week" = "生成第 %d 週個人化課表 · 最佳化強度分配中";
"training.loading.pipeline_step3_fallback" = "生成個人化訓練課表中...";
"training.stage.base" = "基礎期";
"training.stage.build" = "進展期";
"training.stage.peak" = "巔峰期";
"training.stage.taper" = "減量期";
"training.stage.conversion" = "適應期";
"training.stage.unknown" = "訓練中";
"notification.sunday_reminder.title" = "本週訓練完成了 💪";
"notification.sunday_reminder.body" = "今天的訓練成果已準備好，來看看 Paceriz 怎麼評估你這週的表現";
```

- [ ] **Step 3: Add strings to en Localizable.strings**

Find same location and add:
```
"training.loading.pipeline_step1_with_data" = "Analyzing baseline · VDOT %@ · Last week %@ km";
"training.loading.pipeline_step1_vdot_only" = "Analyzing baseline · VDOT %@";
"training.loading.pipeline_step1_fallback" = "Analyzing your training records...";
"training.loading.pipeline_step2_with_data" = "Calculating optimal volume · %@ Week %d of %d";
"training.loading.pipeline_step2_fallback" = "Calculating weekly volume from training history...";
"training.loading.pipeline_step3_with_week" = "Generating Week %d personalized plan · Optimizing intensity";
"training.loading.pipeline_step3_fallback" = "Generating personalized training plan...";
"training.stage.base" = "Base Phase";
"training.stage.build" = "Build Phase";
"training.stage.peak" = "Peak Phase";
"training.stage.taper" = "Taper Phase";
"training.stage.conversion" = "Conversion Phase";
"training.stage.unknown" = "Training";
"notification.sunday_reminder.title" = "Week complete 💪";
"notification.sunday_reminder.body" = "Your training results are ready. See how Paceriz evaluates your week";
```

- [ ] **Step 4: Add strings to ja Localizable.strings**

Find same location and add:
```
"training.loading.pipeline_step1_with_data" = "基礎能力を分析中 · VDOT %@ · 先週の走行距離 %@ km";
"training.loading.pipeline_step1_vdot_only" = "基礎能力を分析中 · VDOT %@";
"training.loading.pipeline_step1_fallback" = "トレーニング記録を分析中...";
"training.loading.pipeline_step2_with_data" = "最適な走行距離を計算中 · %@ 第%d週 / 全%d週";
"training.loading.pipeline_step2_fallback" = "トレーニング履歴から週間距離を計算中...";
"training.loading.pipeline_step3_with_week" = "第%d週のパーソナライズプランを生成中 · 強度配分を最適化中";
"training.loading.pipeline_step3_fallback" = "パーソナライズされたトレーニングプランを生成中...";
"training.stage.base" = "ベース期";
"training.stage.build" = "ビルド期";
"training.stage.peak" = "ピーク期";
"training.stage.taper" = "テーパー期";
"training.stage.conversion" = "アダプテーション期";
"training.stage.unknown" = "トレーニング中";
"notification.sunday_reminder.title" = "今週のトレーニング完了 💪";
"notification.sunday_reminder.body" = "今日のトレーニング結果が準備できました。Pacerizによる週間評価をご確認ください";
```

- [ ] **Step 5: Build to confirm no compile errors**

```bash
cd /Users/wubaizong/havital/apps/ios/Havital
xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Havital/Utils/LocalizationKeys.swift \
        Havital/Resources/zh-Hant.lproj/Localizable.strings \
        Havital/Resources/en.lproj/Localizable.strings \
        Havital/Resources/ja.lproj/Localizable.strings
git commit -m "feat(i18n): add pipeline loading, stage, and Sunday notification strings"
```

---

## Task 2: Create `PlanGenerationContext` struct

**Files:**
- Create: `Havital/Features/TrainingPlanV2/Domain/PlanGenerationContext.swift`
- Create: `HavitalTests/TrainingPlanV2/PlanGenerationContextTests.swift`

- [ ] **Step 1: Write failing tests**

Create `HavitalTests/TrainingPlanV2/PlanGenerationContextTests.swift`:

```swift
import XCTest
@testable import Havital

final class PlanGenerationContextTests: XCTestCase {

    func test_stageIdToLocalizedKey_base() {
        let key = PlanGenerationContext.stageIdToLocalizationKey("base")
        XCTAssertEqual(key, L10n.Training.Stage.base)
    }

    func test_stageIdToLocalizedKey_build() {
        XCTAssertEqual(PlanGenerationContext.stageIdToLocalizationKey("build"), L10n.Training.Stage.build)
    }

    func test_stageIdToLocalizedKey_peak() {
        XCTAssertEqual(PlanGenerationContext.stageIdToLocalizationKey("peak"), L10n.Training.Stage.peak)
    }

    func test_stageIdToLocalizedKey_taper() {
        XCTAssertEqual(PlanGenerationContext.stageIdToLocalizationKey("taper"), L10n.Training.Stage.taper)
    }

    func test_stageIdToLocalizedKey_conversion() {
        XCTAssertEqual(PlanGenerationContext.stageIdToLocalizationKey("conversion"), L10n.Training.Stage.conversion)
    }

    func test_stageIdToLocalizedKey_unknown() {
        XCTAssertEqual(PlanGenerationContext.stageIdToLocalizationKey("BASE"), L10n.Training.Stage.base)  // case-insensitive
        XCTAssertEqual(PlanGenerationContext.stageIdToLocalizationKey("something_else"), L10n.Training.Stage.unknown)
    }

    func test_phaseInfo_returnsNilWhenNoStagesMatch() {
        let info = PlanGenerationContext.phaseInfo(from: [], targetWeek: 3)
        XCTAssertNil(info)
    }

    func test_phaseInfo_returnsCorrectStageAndOffset() {
        let stage = TrainingStageV2(
            stageId: "base", stageName: "基礎期",
            weekStart: 1, weekEnd: 4
        )
        let info = PlanGenerationContext.phaseInfo(from: [stage], targetWeek: 2)
        XCTAssertEqual(info?.localizedKey, L10n.Training.Stage.base)
        XCTAssertEqual(info?.phaseWeek, 2)
        XCTAssertEqual(info?.phaseTotalWeeks, 4)
    }

    func test_phaseInfo_weekOnBoundary() {
        let stage = TrainingStageV2(
            stageId: "peak", stageName: "巔峰期",
            weekStart: 10, weekEnd: 12
        )
        XCTAssertNotNil(PlanGenerationContext.phaseInfo(from: [stage], targetWeek: 10))
        XCTAssertNotNil(PlanGenerationContext.phaseInfo(from: [stage], targetWeek: 12))
        XCTAssertNil(PlanGenerationContext.phaseInfo(from: [stage], targetWeek: 13))
    }
}
```

- [ ] **Step 2: Run test — expect compile failure**

```bash
cd /Users/wubaizong/havital/apps/ios/Havital
xcodebuild test -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' \
  -only-testing:HavitalTests/PlanGenerationContextTests \
  -test-timeouts-enabled YES -defaultTestExecutionTimeAllowance 30 \
  -parallel-testing-enabled NO 2>&1 | grep -E "error:|PASS|FAIL|Build"
```
Expected: compile error `type 'PlanGenerationContext' has no member 'stageIdToLocalizationKey'`

- [ ] **Step 3: Create `PlanGenerationContext.swift`**

```swift
import Foundation

// MARK: - PlanGenerationContext
/// Context snapshot collected from WeeklyPlanLoader immediately before calling
/// repository.generateWeeklyPlan(). Passed to LoadingAnimationView to display
/// data-driven pipeline narrative messages.
struct PlanGenerationContext {
    let weekNumber: Int
    let totalWeeks: Int?
    let vdot: Double?
    let lastWeekVolumeKm: Double?
    let phaseName: String?        // already localized display string
    let phaseWeek: Int?           // e.g. 2 (within phase)
    let phaseTotalWeeks: Int?     // e.g. 4 (total weeks in phase)
}

// MARK: - Builder helpers (internal for tests)

extension PlanGenerationContext {

    /// Maps a stage ID string to its L10n key. Internal so tests can reach it.
    static func stageIdToLocalizationKey(_ stageId: String) -> String {
        switch stageId.lowercased() {
        case "base":       return L10n.Training.Stage.base
        case "build":      return L10n.Training.Stage.build
        case "peak":       return L10n.Training.Stage.peak
        case "taper":      return L10n.Training.Stage.taper
        case "conversion": return L10n.Training.Stage.conversion
        default:           return L10n.Training.Stage.unknown
        }
    }

    struct PhaseInfo {
        let localizedKey: String
        let phaseWeek: Int
        let phaseTotalWeeks: Int
    }

    /// Find the phase that contains targetWeek and compute week-within-phase offset.
    static func phaseInfo(from stages: [TrainingStageV2], targetWeek: Int) -> PhaseInfo? {
        guard let stage = stages.first(where: { $0.containsWeek(targetWeek) }) else { return nil }
        return PhaseInfo(
            localizedKey: stageIdToLocalizationKey(stage.stageId),
            phaseWeek: targetWeek - stage.weekStart + 1,
            phaseTotalWeeks: stage.totalWeeks
        )
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
xcodebuild test -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' \
  -only-testing:HavitalTests/PlanGenerationContextTests \
  -test-timeouts-enabled YES -defaultTestExecutionTimeAllowance 30 \
  -parallel-testing-enabled NO 2>&1 | grep -E "Test.*passed|Test.*failed|error:"
```
Expected: `Test Suite 'PlanGenerationContextTests' passed`

- [ ] **Step 5: Commit**

```bash
git add Havital/Features/TrainingPlanV2/Domain/PlanGenerationContext.swift \
        HavitalTests/TrainingPlanV2/PlanGenerationContextTests.swift
git commit -m "feat(loading): add PlanGenerationContext struct with stage-mapping helpers"
```

---

## Task 3: Update `LoadingAnimationView` — pipeline narrative messages

**Files:**
- Modify: `Havital/Views/Common/LoadingAnimationView.swift`

- [ ] **Step 1: Add `context` parameter and dynamic `messages(for:)` helper**

The view currently derives `messages` from `type.messages` in `init`. We need to override that when `context` is provided and `type == .generatePlan`.

Replace the entire `LoadingAnimationView` `init` and `LoadingType.messages` section with:

```swift
// In LoadingType enum, add — existing cases unchanged:
case generatePlanWithContext(PlanGenerationContext)

// NEW computed var that replaces the old messages array:
var messages: [String] {
    switch self {
    case .generatePlan:
        return [
            L10n.Training.LoadingAnimation.analyzingFitness.localized,
            L10n.Training.LoadingAnimation.planningIntensity.localized,
            L10n.Training.LoadingAnimation.preparingCustomPlan.localized
        ]
    case .generatePlanWithContext(let ctx):
        return LoadingAnimationView.pipelineMessages(for: ctx)
    case .generateReview:
        return [
            L10n.Training.LoadingAnimation.analyzingTrainingData.localized,
            L10n.Training.LoadingAnimation.evaluatingProgress.localized,
            L10n.Training.LoadingAnimation.preparingReview.localized
        ]
    case .custom(let messages):
        return messages
    }
}
```

Wait — this requires adding a static helper to `LoadingAnimationView`. Instead, let's keep it simpler: keep the `LoadingType` enum unchanged, add `context` only to the struct-level init.

Replace both `init` methods with these three:

```swift
/// Existing init — keeps full backward compatibility.
init(type: LoadingType = .generatePlan, totalDuration: Double = 25) {
    self.messages = type.messages
    self.totalDuration = totalDuration
}

/// New init — when context is provided for .generatePlan, builds pipeline messages.
/// For any other type the context is ignored.
init(type: LoadingType = .generatePlan, context: PlanGenerationContext?, totalDuration: Double = 25) {
    if case .generatePlan = type, let ctx = context {
        self.messages = LoadingAnimationView.pipelineMessages(for: ctx)
    } else {
        self.messages = type.messages
    }
    self.totalDuration = totalDuration
}

/// Existing custom-messages init — unchanged.
init(messages: [String], totalDuration: Double = 25) {
    self.init(type: .custom(messages), totalDuration: totalDuration)
}
```

Then add the static helper **inside `LoadingAnimationView`** (before the preview block):

```swift
// MARK: - Pipeline messages builder
static func pipelineMessages(for ctx: PlanGenerationContext) -> [String] {
    // Step 1: VDOT + last week volume
    let step1: String = {
        let vdotStr = ctx.vdot.map { String(format: "%.1f", $0) }
        let volStr  = ctx.lastWeekVolumeKm.map { String(format: "%.0f", $0) }
        if let v = vdotStr, let km = volStr {
            return L10n.Training.LoadingAnimation.pipelineStep1WithData.localized(with: v, km)
        } else if let v = vdotStr {
            return L10n.Training.LoadingAnimation.pipelineStep1VdotOnly.localized(with: v)
        } else {
            return L10n.Training.LoadingAnimation.pipelineStep1Fallback.localized
        }
    }()

    // Step 2: phase name + week-in-phase
    let step2: String = {
        if let name = ctx.phaseName,
           let pw = ctx.phaseWeek,
           let pt = ctx.phaseTotalWeeks {
            return L10n.Training.LoadingAnimation.pipelineStep2WithData.localized(with: name, pw, pt)
        } else {
            return L10n.Training.LoadingAnimation.pipelineStep2Fallback.localized
        }
    }()

    // Step 3: target week number
    let step3: String = {
        return L10n.Training.LoadingAnimation.pipelineStep3WithWeek.localized(with: ctx.weekNumber)
    }()

    return [step1, step2, step3]
}
```

- [ ] **Step 2: Build to confirm no compile errors**

```bash
xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Havital/Views/Common/LoadingAnimationView.swift
git commit -m "feat(loading): add context parameter for pipeline narrative messages"
```

---

## Task 4: Add new ViewModel state

**Files:**
- Modify: `Havital/Features/TrainingPlanV2/Presentation/ViewModels/TrainingPlanV2ViewModel.swift`

- [ ] **Step 1: Add two new state properties**

In the `// MARK: - Orchestration State` section (around line 29–34), add after `isLoadingAnimation`:

```swift
var loadingAnimationContext: PlanGenerationContext? = nil
var shouldAutoShowWeekTarget: Bool = false
```

- [ ] **Step 2: Update the `setLoadingAnimation` closure in generator initialization**

Find the `self.generator = WeeklyPlanGenerator(...)` block (around line 129). The `setLoadingAnimation` closure currently is:

```swift
setLoadingAnimation: { [weak self] value in self?.isLoadingAnimation = value },
```

Change it to:

```swift
setLoadingAnimation: { [weak self] value, context in
    self?.isLoadingAnimation = value
    self?.loadingAnimationContext = context
},
```

- [ ] **Step 3: Update the `setLoadingAnimation` closure for the summary coordinator**

The `summary` coordinator also has a `setLoadingAnimation` closure (around line 114):

```swift
setLoadingAnimation: { [weak self] value in self?.isLoadingAnimation = value },
```

The `WeeklySummaryCoordinator` doesn't use context (it generates reviews, not plans), so its closure stays as `(Bool) -> Void`. No change needed here.

- [ ] **Step 4: Build**

```bash
xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet 2>&1 | tail -5
```

Expected: compile error because `WeeklyPlanGenerator.setLoadingAnimation` still has the old `(Bool) -> Void` signature. We fix that in Task 5.

- [ ] **Step 5: Commit partial (ViewModel state additions only)**

```bash
git add Havital/Features/TrainingPlanV2/Presentation/ViewModels/TrainingPlanV2ViewModel.swift
git commit -m "feat(plan-gen): add loadingAnimationContext and shouldAutoShowWeekTarget to ViewModel"
```

---

## Task 5: Update `WeeklyPlanGenerator` — collect context + set auto-show flag

**Files:**
- Modify: `Havital/Features/TrainingPlanV2/Presentation/ViewModels/WeeklyPlanGenerator.swift`

> **Timing requirement:** `loadingAnimationContext` must be set BEFORE `isLoadingAnimation = true`, otherwise the `LoadingAnimationView` sheet is already initialised with nil context when it captures the value. The fix is to pass context into `prepareForGeneration()` so the single `setLoadingAnimation(true, context)` call is done there.

- [ ] **Step 1: Update `setLoadingAnimation` stored closure signature**

Find (around line 22):
```swift
@ObservationIgnored private let setLoadingAnimation: (Bool) -> Void
```
Change to:
```swift
@ObservationIgnored private let setLoadingAnimation: (Bool, PlanGenerationContext?) -> Void
```

Find the init parameter (around line 39):
```swift
setLoadingAnimation: @escaping (Bool) -> Void,
```
Change to:
```swift
setLoadingAnimation: @escaping (Bool, PlanGenerationContext?) -> Void,
```

- [ ] **Step 2: Add `onPlanGenerated` callback**

After the existing `onNetworkError` property declaration:
```swift
@ObservationIgnored private let onPlanGenerated: (() -> Void)?
```

Add to init parameters after `onNetworkError`:
```swift
onPlanGenerated: (() -> Void)? = nil
```

In init body after `self.onNetworkError = onNetworkError`:
```swift
self.onPlanGenerated = onPlanGenerated
```

- [ ] **Step 3: Add context builder helper**

At the bottom of `WeeklyPlanGenerator` (before `// MARK: - Private Helpers`), add:

```swift
// MARK: - Context Builder

private func buildGenerationContext(forWeek weekNumber: Int) -> PlanGenerationContext {
    let previousPlan = loader.weeklyPlan
    let overview = loader.planOverview

    let vdot = previousPlan?.currentVdot

    // Show last week's volume only when the cached plan is exactly week N-1
    let lastWeekVolumeKm: Double? = {
        guard let prev = previousPlan else { return nil }
        let prevWeek = prev.weekOfTraining ?? prev.weekOfPlan ?? 0
        return (prevWeek == weekNumber - 1) ? prev.totalDistance : nil
    }()

    var phaseName: String?
    var phaseWeek: Int?
    var phaseTotalWeeks: Int?

    if let stages = overview?.trainingStages,
       let info = PlanGenerationContext.phaseInfo(from: stages, targetWeek: weekNumber) {
        phaseName = info.localizedKey.localized
        phaseWeek = info.phaseWeek
        phaseTotalWeeks = info.phaseTotalWeeks
    }

    return PlanGenerationContext(
        weekNumber: weekNumber,
        totalWeeks: overview?.totalWeeks,
        vdot: vdot,
        lastWeekVolumeKm: lastWeekVolumeKm,
        phaseName: phaseName,
        phaseWeek: phaseWeek,
        phaseTotalWeeks: phaseTotalWeeks
    )
}
```

- [ ] **Step 4: Refactor `prepareForGeneration()` to accept context**

`prepareForGeneration()` currently calls `setLoadingAnimation(true)` BEFORE the caller has a chance to build context. We fix this by passing context in:

Find `prepareForGeneration()` (around line 239). Change its signature and the `setLoadingAnimation` call:

```swift
private func prepareForGeneration(context: PlanGenerationContext? = nil) async -> Bool {
    // S07 gating: enforce subscription check for Week 2+ (AC-PAYWALL-25/26/27)
    let week = loader.selectedWeek
    if week >= 2,
       SubscriptionStateManager.shared.isEnforcementEnabled,
       !SubscriptionStateManager.shared.hasPremiumAccess {
        onWeeklyPlanInlineUpsellNeeded?(false)
        Logger.debug("[WeeklyPlanGenerator] ⛔ Week \(week) 課表被 gate：顯示 weekly_plan inline upsell card")
        return false
    }

    summary.isLoadingWeeklySummary = false
    setLoadingAnimation(true, context)   // ← pass context here so sheet captures it at init time

    if await shouldBlockByRizoQuota() {
        onRizoQuotaExceeded()
        setLoadingAnimation(false, nil)
        return false
    }
    return true
}
```

Also find the other `setLoadingAnimation(true)` call in `updateOverview()` (around line 201) and change to:
```swift
setLoadingAnimation(true, nil)
```

And find `setLoadingAnimation(false)` calls in `prepareForGeneration` / `handleGenerationError` and change to `setLoadingAnimation(false, nil)`.

- [ ] **Step 5: Update `generateCurrentWeekPlan()` to build context and set auto-show**

In `generateCurrentWeekPlan()`, find:
```swift
guard await prepareForGeneration() else { return }
```
Replace with:
```swift
let context = buildGenerationContext(forWeek: loader.selectedWeek)
guard await prepareForGeneration(context: context) else { return }
```

After `loader.planStatus = .ready(plan)` in the success block, add:
```swift
onPlanGenerated?()
```

- [ ] **Step 6: Update `generateWeeklyPlanDirectly()` to build context and set auto-show**

In `generateWeeklyPlanDirectly(weekNumber:managedLoadingExternally:)`, find the block:
```swift
if !managedLoadingExternally {
    guard await prepareForGeneration() else { return }
} else {
```
Change to:
```swift
if !managedLoadingExternally {
    let context = buildGenerationContext(forWeek: weekNumber)
    guard await prepareForGeneration(context: context) else { return }
} else {
```

After `loader.planStatus = .ready(plan)` in the success block, add:
```swift
if !managedLoadingExternally {
    onPlanGenerated?()
}
```

(Don't trigger auto-show when called from inside the summary flow, where the sheet lifecycle is managed externally.)

- [ ] **Step 7: Wire `onPlanGenerated` in `TrainingPlanV2ViewModel`**

In `TrainingPlanV2ViewModel.swift`, in the `self.generator = WeeklyPlanGenerator(...)` init call, add after `onNetworkError`:
```swift
onPlanGenerated: { [weak self] in self?.shouldAutoShowWeekTarget = true },
```

- [ ] **Step 8: Build to confirm no compile errors**

```bash
xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: Commit**

```bash
git add Havital/Features/TrainingPlanV2/Presentation/ViewModels/WeeklyPlanGenerator.swift \
        Havital/Features/TrainingPlanV2/Presentation/ViewModels/TrainingPlanV2ViewModel.swift
git commit -m "feat(plan-gen): collect context before generation, trigger auto-show after success"
```

---

## Task 6: Update `WeekOverviewCardV2` — add `autoShowTarget` binding

**Files:**
- Modify: `Havital/Features/TrainingPlanV2/Presentation/Views/Components/WeekOverviewCardV2.swift`

- [ ] **Step 1: Add `@Binding var autoShowTarget: Bool`**

Find the struct declaration (line 14):
```swift
struct WeekOverviewCardV2: View {
    var viewModel: TrainingPlanV2ViewModel
    @ObservedObject private var unitManager = UnitManager.shared
    @Environment(\.colorScheme) var colorScheme
    let plan: WeeklyPlanV2
    @State private var showWeekTargetDetail = false
```

Add after `let plan: WeeklyPlanV2`:
```swift
@Binding var autoShowTarget: Bool
```

- [ ] **Step 2: Add `.onChange` modifier to the card body**

Find the `.accessibilityIdentifier("v2.weekly.overview_card")` modifier and add after it:

```swift
.onChange(of: autoShowTarget) { _, shouldShow in
    guard shouldShow else { return }
    showWeekTargetDetail = true
    autoShowTarget = false
}
```

- [ ] **Step 3: Add default parameter for preview and existing call site safety**

Add a convenience init or leave the binding required (caller provides). Since `WeekOverviewCardV2` is only called from `TrainingPlanV2View`, the binding is always available. No default needed.

- [ ] **Step 4: Build — expect compiler error from call site**

```bash
xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet 2>&1 | grep "error:" | head -5
```
Expected: error in `TrainingPlanV2View.swift` — missing `autoShowTarget` argument.

- [ ] **Step 5: Commit partial**

```bash
git add Havital/Features/TrainingPlanV2/Presentation/Views/Components/WeekOverviewCardV2.swift
git commit -m "feat(goal-sheet): add autoShowTarget binding to WeekOverviewCardV2"
```

---

## Task 7: Update `TrainingPlanV2View` — thread context, auto-show binding, Sunday reminder trigger

**Files:**
- Modify: `Havital/Features/TrainingPlanV2/Presentation/Views/TrainingPlanV2View.swift`

- [ ] **Step 1: Add `autoShowWeekTarget` state variable**

Find `@State private var showOverviewV2 = false` and add below it:

```swift
@State private var autoShowWeekTarget = false
```

- [ ] **Step 2: Update `WeekOverviewCardV2` call to pass binding**

Find (around line 179):
```swift
WeekOverviewCardV2(viewModel: viewModel, plan: weeklyPlan)
```
Change to:
```swift
WeekOverviewCardV2(viewModel: viewModel, plan: weeklyPlan, autoShowTarget: $autoShowWeekTarget)
```

- [ ] **Step 3: Observe `shouldAutoShowWeekTarget` flag and set binding**

Find the `.onChange(of: viewModel.loader.planStatus)` block and add a new `.onChange` AFTER it:

```swift
.onChange(of: viewModel.shouldAutoShowWeekTarget) { _, flag in
    guard flag else { return }
    viewModel.shouldAutoShowWeekTarget = false
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        autoShowWeekTarget = true
    }
}
```

- [ ] **Step 4: Thread context into the `LoadingAnimationView` sheet**

Find the standalone loading sheet (around line 434–438):
```swift
.sheet(isPresented: $bindableViewModel.isLoadingAnimation) {
    LoadingAnimationView(type: .generatePlan, totalDuration: 12.0)
        .ignoresSafeArea()
        .interactiveDismissDisabled(true)
}
```

Change to:
```swift
.sheet(isPresented: $bindableViewModel.isLoadingAnimation) {
    LoadingAnimationView(
        type: .generatePlan,
        context: viewModel.loadingAnimationContext,
        totalDuration: 12.0
    )
    .ignoresSafeArea()
    .interactiveDismissDisabled(true)
}
```

Also find the `case .loadingPlan:` inside the summary flow sheet (around line 521):
```swift
case .loadingPlan:
    LoadingAnimationView(type: .generatePlan, totalDuration: 12.0)
        .ignoresSafeArea()
        .interactiveDismissDisabled(true)
```

Change to:
```swift
case .loadingPlan:
    LoadingAnimationView(
        type: .generatePlan,
        context: viewModel.loadingAnimationContext,
        totalDuration: 12.0
    )
    .ignoresSafeArea()
    .interactiveDismissDisabled(true)
```

- [ ] **Step 5: Add Sunday reminder trigger in `.task(id: scenePhase)`**

Find the `.task(id: scenePhase)` block (around line 712–721). After `await viewModel.loader.initialize()` line, add:

```swift
// Sunday reminder: schedule 8pm notification if conditions are met
if case .ready(let plan) = viewModel.loader.planStatus {
    let todayWorkoutsExist = viewModel.loader.workoutsByDay.values.flatMap { $0 }.contains {
        Calendar.current.isDateInToday($0.startDate)
    }
    WeeklySundayReminderService.shared.checkAndScheduleIfNeeded(
        weeklyPlan: plan,
        todayWorkoutExists: todayWorkoutsExist
    )
}
```

- [ ] **Step 6: Build to confirm no errors**

```bash
xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet 2>&1 | tail -5
```
Expected: compile error because `WeeklySundayReminderService` doesn't exist yet. That's fine — we'll fix in Task 8.

- [ ] **Step 7: Commit**

```bash
git add Havital/Features/TrainingPlanV2/Presentation/Views/TrainingPlanV2View.swift
git commit -m "feat(plan-gen): wire context + auto-show binding + Sunday reminder trigger in View"
```

---

## Task 8: Create `WeeklySundayReminderService` and register in DI

**Files:**
- Create: `Havital/Features/TrainingPlanV2/Domain/WeeklySundayReminderService.swift`
- Modify: `Havital/Core/DI/AppDependencyBootstrap.swift`

- [ ] **Step 1: Create `WeeklySundayReminderService.swift`**

```swift
import UserNotifications
import Foundation

// MARK: - WeeklySundayReminderService
/// Schedules a local notification at 20:00 every Sunday when:
///   1. Today is Sunday
///   2. The current week's Sunday has a non-rest training day
///   3. The user recorded at least one workout today
///
/// Idempotent: cancels any pending notification with the same identifier
/// before scheduling a new one. Safe to call multiple times per day.
@MainActor
final class WeeklySundayReminderService {

    static let shared = WeeklySundayReminderService()

    private let notificationIdentifier = "weekly_sunday_reminder"

    private init() {}

    func checkAndScheduleIfNeeded(weeklyPlan: WeeklyPlanV2, todayWorkoutExists: Bool) {
        guard isSunday() else { return }
        guard hasSundayTraining(in: weeklyPlan) else { return }
        guard todayWorkoutExists else { return }
        // Already past 20:00 → no point scheduling
        guard !isPast8pm() else { return }

        Task {
            await scheduleNotification()
        }
    }

    // MARK: - Condition Checks

    private func isSunday() -> Bool {
        Calendar.current.component(.weekday, from: Date()) == 1  // 1 = Sunday in Gregorian
    }

    private func isPast8pm() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 20
    }

    /// Sunday is dayIndex == 7 in the plan's days array (1=Monday … 7=Sunday).
    /// Returns true when the plan has any non-rest activity scheduled on Sunday.
    func hasSundayTraining(in plan: WeeklyPlanV2) -> Bool {
        guard let sunday = plan.days.first(where: { $0.dayIndex == 7 }) else { return false }
        return sunday.category != .rest && sunday.category != nil
    }

    // MARK: - Notification Scheduling

    private func scheduleNotification() async {
        let center = UNUserNotificationCenter.current()

        // Remove any pending notification from a prior call today
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = L10n.Notification.SundayReminder.title.localized
        content.body  = L10n.Notification.SundayReminder.body.localized
        content.sound = .default

        // Fire at 20:00 today (local time)
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour   = 20
        components.minute = 0
        components.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            Logger.debug("[WeeklySundayReminderService] ✅ Sunday 20:00 notification scheduled")
        } catch {
            Logger.error("[WeeklySundayReminderService] ❌ Failed to schedule: \(error)")
        }
    }
}
```

- [ ] **Step 2: Register in `AppDependencyBootstrap.swift`**

`WeeklySundayReminderService` uses `shared` — no DI registration needed for a singleton accessed via `.shared`. The service is already usable from `TrainingPlanV2View` via `WeeklySundayReminderService.shared`.

However, make sure the file is in the Xcode target. Check if you need to add it to the build target:

```bash
grep -r "WeeklySundayReminderService" /Users/wubaizong/havital/apps/ios/Havital/Havital.xcodeproj 2>/dev/null | head -3
```

If the file isn't listed in the `.pbxproj`, add it via Xcode or by verifying the directory glob includes it (most Xcode projects use folder references for Swift files — if so, the file is automatically included).

- [ ] **Step 3: Build — must pass**

```bash
xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Havital/Features/TrainingPlanV2/Domain/WeeklySundayReminderService.swift
git commit -m "feat(notification): add WeeklySundayReminderService for Sunday 20:00 local notification"
```

---

## Task 9: Clean build + end-to-end verification

- [ ] **Step 1: Full clean build**

```bash
xcodebuild clean build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **` with zero new errors/warnings.

- [ ] **Step 2: Run existing tests**

```bash
xcodebuild test -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' \
  -test-timeouts-enabled YES -defaultTestExecutionTimeAllowance 60 \
  -parallel-testing-enabled NO \
  -only-testing:HavitalTests/PlanGenerationContextTests \
  2>&1 | grep -E "Test Suite|passed|failed"
```
Expected: all pass.

- [ ] **Step 3: Simulator smoke test — Loading screen**

Using iOS Simulator MCP tools:
1. Launch the app and log in to a test account that has a training plan
2. Navigate to the training plan tab
3. Delete the current week's plan (debug menu: 🗑️ 刪除當前週課表)
4. Tap the generate button
5. Observe the loading sheet — the first message should show VDOT and volume data (not the generic fallback text)
6. Take a screenshot confirming the pipeline message is visible

- [ ] **Step 4: Simulator smoke test — Auto-show goal sheet**

1. After the plan generates (from Step 3 above), confirm the "本週目標" sheet auto-appears
2. The sheet should show coachNote + purpose + designReason from the new plan
3. Dismiss the sheet manually and confirm the main plan view is visible

- [ ] **Step 5: Verify Sunday notification logic**

In simulator, trigger the reminder service check with a Saturday to confirm it doesn't schedule:

Open the debug console or add a temporary log call. Since this is conditional on Sunday, the easiest verification is unit-level. Optionally run on the Sunday date by overriding device date in Simulator → Device → Set Custom Date to a Sunday.

- [ ] **Step 6: Run `/simplify` on changed files**

Per delivery rules, run simplification pass after feature implementation.

- [ ] **Step 7: Final commit**

```bash
git add -A
git commit -m "feat: loading context, auto goal sheet, Sunday push notification (3 features)"
```

---

## Spec Coverage Check

| Spec Requirement | Covered By |
|---|---|
| Feature 1: PlanGenerationContext struct | Task 2 |
| Feature 1: 3-step pipeline messages with data | Task 3 |
| Feature 1: Fallback when data unavailable | Task 3, `pipelineMessages(for:)` |
| Feature 1: Context collected before generation | Task 5 |
| Feature 1: All 3 locale strings | Task 1 |
| Feature 2: `shouldAutoShowWeekTarget` flag | Task 4, 5 |
| Feature 2: 0.5s delay before showing sheet | Task 7, Step 3 |
| Feature 2: `WeekOverviewCardV2` Binding | Task 6 |
| Feature 3: Sunday condition check | Task 8 |
| Feature 3: todayWorkoutExists check | Task 7, Step 5 |
| Feature 3: 20:00 UNCalendarNotificationTrigger | Task 8 |
| Feature 3: Idempotent (remove before schedule) | Task 8 |
| Feature 3: All 3 locale notification strings | Task 1 |
