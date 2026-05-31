---
type: TD
id: TD-readiness-v2-conditional-display
status: Draft
spec: SPEC-readiness-v2-conditional-display.md
created: 2026-04-28
updated: 2026-04-28
---

# 技術設計: Readiness V2 — 依 plan_type 條件顯示

## AC Compliance Matrix

| AC ID | AC 描述 | 實作位置 | Test Function | 狀態 |
|-------|--------|---------|---------------|------|
| AC-RDNS-01 | race_run → 5 維齊全 | `TrainingReadinessView`, `TrainingReadinessViewModel.effectivePlanType` | `test_ac_rdns_01_race_run_shows_all` | STUB |
| AC-RDNS-02 | beginner → 只 speed + training_load | `TrainingReadinessView`, `ReadinessPlanType.beginner` | `test_ac_rdns_02_beginner_shows_two_cards` | STUB |
| AC-RDNS-03 | maintenance → 同 beginner | `TrainingReadinessView`, `ReadinessPlanType.maintenance` | `test_ac_rdns_03_maintenance_shows_two_cards` | STUB |
| AC-RDNS-04 | V1 fallback → PlanOverviewV2.targetType | `TrainingReadinessViewModel.effectivePlanType` | `test_ac_rdns_04_fallback_to_plan_overview` | STUB |
| AC-RDNS-05 | plan switch → readiness refresh | `TrainingReadinessManager.setupOverviewObserver` | `test_ac_rdns_05_plan_switch_triggers_refresh` | STUB |

## Component 架構

```
TrainingReadinessView
  └─ @StateObject TrainingReadinessViewModel
        ├─ TrainingReadinessManager.shared (existing, deprecated)
        │    ├─ TrainingReadinessService (fetch API)
        │    ├─ TrainingReadinessStorage (cache)
        │    └─ [NEW] overviewRepo: TrainingPlanV2Repository
        │         └─ overviewDidUpdate.sink → forceRefresh()
        └─ [NEW] planOverviewProvider: () -> PlanOverviewV2?
             └─ fallback source for planType

TrainingReadinessResponse [NEW field]
  └─ planType: String?  (CodingKey: "plan_type")

ReadinessPlanType [NEW enum, Domain layer]
  ├─ .raceRun / .beginner / .maintenance / .unknown
  └─ shouldShowRadar / shouldShowOverallScore / shouldShowEstimatedRaceTime / shouldShowStatusText

TrainingReadinessViewModel [NEW computed]
  └─ effectivePlanType: ReadinessPlanType
       1. readinessData?.planType → decode
       2. nil → planOverviewProvider()?.targetType → decode
       3. nil → .unknown (default: show all)
```

## 介面合約清單

| 型別/函式 | 參數 | 說明 |
|-----------|------|------|
| `TrainingReadinessResponse.planType` | `String?` | CodingKey `"plan_type"`; nil = V1 舊 doc |
| `ReadinessPlanType` enum | rawValue: `String` | `"race_run"` / `"beginner"` / `"maintenance"` |
| `ReadinessPlanType.shouldShowRadar` | computed `Bool` | true 僅 .raceRun |
| `ReadinessPlanType.shouldShowOverallScore` | computed `Bool` | true 僅 .raceRun |
| `ReadinessPlanType.shouldShowEstimatedRaceTime` | computed `Bool` | true 僅 .raceRun |
| `ReadinessPlanType.shouldShowStatusText` | computed `Bool` | true 僅 .raceRun |
| `TrainingReadinessViewModel.effectivePlanType` | computed → `ReadinessPlanType` | fallback chain as above |
| `TrainingReadinessManager.init(overviewRepo:)` | `TrainingPlanV2Repository?` | 注入 repo 用於訂閱 overviewDidUpdate |

## DB Schema 變更

無。`planType` 只是新解碼欄位，Storage 存既有 `TrainingReadinessResponse`（`Codable`），加欄位後自動序列化。

## 任務拆分

| # | 任務 | Done Criteria |
|---|------|--------------|
| S01 | **Data + Domain 層** | `TrainingReadinessResponse` 加 `planType: String?`（CodingKey `plan_type`）；`ReadinessPlanType` enum 定義所有 should* computed；unit test 覆蓋 JSON 解碼 + 4 個 planType 值的 should* 正確性 → AC test `test_ac_rdns_01/02/03` 的 model 部分 PASS |
| S02 | **ViewModel fallback** | `TrainingReadinessViewModel` 加 `planOverviewProvider: () -> PlanOverviewV2?`；實作 `effectivePlanType` fallback chain；unit test 覆蓋 4 場景（doc 有 / doc 無+overview 有 / 兩者皆無 / unknown default）→ `test_ac_rdns_04` PASS |
| S03 | **View 條件渲染** | `TrainingReadinessView.contentView` 用 `viewModel.effectivePlanType.shouldShow*` 包住 overallScoreSection + radarChartView + estimatedRaceTime + statusText；metricsGrid 已靠 optional 自動 hide endurance/race_fitness/recovery；干淨 build pass；simulator 截圖三種 plan_type 各一張 |
| S04 | **Cache invalidation** | `TrainingReadinessManager` 注入 `TrainingPlanV2Repository`（預設值 `TrainingPlanV2RepositoryImpl.shared`）；訂閱 `overviewDidUpdate`，收到後呼叫 `forceRefresh()`；unit test mock repo + spy 確認 forceRefresh 被呼叫 → `test_ac_rdns_05` PASS |

## Done Criteria（整體）

- [ ] AC-RDNS-01 ~ AC-RDNS-05 全部從 FAIL 變 PASS（`HavitalTests/TrainingPlan/Spec/ReadinessConditionalDisplayACTests.swift`）
- [ ] `xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` 零錯誤
- [ ] simulator 截圖：race_run（5 張卡 + 雷達）、beginner（2 張卡，無雷達）、maintenance（同 beginner）三種各一張

## Risk Assessment

### 1. 不確定的技術點
- `TrainingReadinessManager` 是 deprecated singleton；注入 `overviewRepo` 依賴需確認 `DependencyContainer` 是否已有 `TrainingPlanV2RepositoryImpl.shared`（可直接拿，不走 DI container）。

### 2. 替代方案
- **方案 A（採用）**：plan_type enum 放 Domain layer，ViewModel 做 fallback，View 純 if 包。侵入最小。
- **方案 B**：Manager 完全重構為 UseCase pattern。Blast radius 太大，留給後續 refactor sprint。

### 3. 需要 Developer 確認
- `TrainingPlanV2RepositoryImpl.shared` singleton 是否可在 `TrainingReadinessManager.init` 直接引用（避免 circular dependency）。

### 4. 最壞情況
- fallback chain 有 bug → race_run 用戶看不到 race_fitness 卡。修復成本低：只改 enum rawValue 對應。Maestro flow 必須涵蓋三種切換。
