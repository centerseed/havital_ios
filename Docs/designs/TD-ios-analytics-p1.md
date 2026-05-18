---
type: TD
id: TD-ios-analytics-p1
spec: SPEC-ios-analytics-p1
status: Ready
created: 2026-05-05
updated: 2026-05-05
---

# 技術設計：iOS Analytics P1（漏斗精細化 + 核心 view）

## 調查報告（搬自 Architect Phase 0）

### 已讀文件
- `cloud/api_service/docs/01-specs/SPEC-analytics-event-tracking.md` — P1 §4 已定義 5 個 view 事件 schema；onboarding 精細化 8 事件為本 sub-spec 新增
- `apps/ios/Havital/Docs/specs/SPEC-ios-analytics-p0.md` — P0 sub-spec 結構，AC-IOS-ANALYTICS-01..12，本 sub-spec 沿用 `AC-IOS-ANALYTICS-P1-NN` 命名
- `apps/ios/Havital/Havital/Core/Analytics/AnalyticsEvent.swift:7-49` — 11 個既有 case，新增 13 個 case 沿用同 enum + switch pattern
- `apps/ios/Havital/Havital/Features/Onboarding/Presentation/Coordinators/OnboardingCoordinator.swift:18-48,163` — 16 個 Step enum；nav 機制為 `navigationPath.append(step)`
- `apps/ios/Havital/Havital/Features/Onboarding/Presentation/ViewModels/OnboardingFeatureViewModel.swift:388,586,937` — 既有 `onboardingTargetSet` 三處 trigger
- `apps/ios/Havital/docs/plans/PLAN-analytics-tracking-reconciliation.md`（status=done）— P0 收斂 plan 已關帳；本次為 P1 新 plan

### 已確認 trigger 候選位置
- `weekly_plan_view` → `Havital/Features/TrainingPlanV2/Presentation/Views/TrainingPlanV2View.swift`
- `weekly_summary_view` → `Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift`
- `plan_overview_view` → `Havital/Features/TrainingPlanV2/Presentation/Views/Components/PlanOverviewSheetV2.swift`
- `workout_analysis_view` → `Havital/Features/Workout/Presentation/Views/...`（對應 `WorkoutDetailViewModelV2`）— Developer 自行定位精確 view file
- `race_prediction_view` → 待 Developer 階段 grep `predicted_time` / `RacePrediction` 定位

### 不確定（[未確認]）
- `race_prediction_view` 與 `workout_analysis_view` 的具體 view file 名稱 — Developer 自行 grep 定位
- onboarding step 完成時點是「按 Next 觸發 navigationPath.append」還是 view `onDisappear` — Developer 階段選一致 pattern（推薦：在 step view 的「Next button action」呼叫 track，與 `onboardingTargetSet` 既有埋點點一致）

### 結論
可開始 Developer dispatch。13 個 trigger 中 8 個位置明確，5 個 view 中 3 個明確、2 個由 Developer grep 定位。

## AC Compliance Matrix

| AC ID | AC 描述 | 實作位置（建議） | Test Function | 狀態 |
|-------|--------|----------------|---------------|------|
| AC-IOS-ANALYTICS-P1-01 | AnalyticsEvent enum 擴 13 case | `Core/Analytics/AnalyticsEvent.swift` | `test_p1_01_enum_cases_present` | STUB |
| AC-IOS-ANALYTICS-P1-02 | onboarding_data_source_prompted（.dataSource onAppear） | onboarding `.dataSource` step view onAppear | `test_p1_02_data_source_prompted_emitted` | STUB |
| AC-IOS-ANALYTICS-P1-03 | onboarding_data_source_skipped（skip flow） | `.dataSource` step skip action | `test_p1_03_data_source_skipped_emitted` | STUB |
| AC-IOS-ANALYTICS-P1-04 | onboarding_data_source_connected（含 provider） | Garmin OAuth callback / Apple Health 授權 callback | `test_p1_04_data_source_connected_with_provider` | STUB |
| AC-IOS-ANALYTICS-P1-05 | onboarding_goal_type_selected（含 target_type） | `OnboardingFeatureViewModel`（`.goalType` 完成） | `test_p1_05_goal_type_selected_with_target_type` | STUB |
| AC-IOS-ANALYTICS-P1-06 | onboarding_target_race_set（含 race_id / distance_km） | `OnboardingFeatureViewModel`（`.raceEventList` / `.maintenanceRaceDistance` 完成） | `test_p1_06_target_race_set_params` | STUB |
| AC-IOS-ANALYTICS-P1-07 | onboarding_schedule_set（含 available_days） | `OnboardingFeatureViewModel`（`.trainingDays` 完成） | `test_p1_07_schedule_set_with_available_days` | STUB |
| AC-IOS-ANALYTICS-P1-08 | onboarding_plan_generating（含 target_type） | `.trainingOverview` view onAppear | `test_p1_08_plan_generating_emitted` | STUB |
| AC-IOS-ANALYTICS-P1-09 | weekly_plan_view（plan_id, week_of_training） | `TrainingPlanV2View.onAppear` | `test_p1_09_weekly_plan_view_params` | STUB |
| AC-IOS-ANALYTICS-P1-10 | workout_analysis_view（workout_id, has_coach_notes） | workout detail view onAppear | `test_p1_10_workout_analysis_view_params` | STUB |
| AC-IOS-ANALYTICS-P1-11 | weekly_summary_view（summary_id, week_of_training） | `WeeklySummaryV2View.onAppear` | `test_p1_11_weekly_summary_view_params` | STUB |
| AC-IOS-ANALYTICS-P1-12 | plan_overview_view（overview_id, target_type） | `PlanOverviewSheetV2.onAppear` | `test_p1_12_plan_overview_view_params` | STUB |
| AC-IOS-ANALYTICS-P1-13 | race_prediction_view（predicted_time, distance_km） | race prediction view onAppear | `test_p1_13_race_prediction_view_params` | STUB |

**Test stub file**：`apps/ios/Havital/HavitalTests/SpecCompliance/IosAnalyticsP1ACTests.swift`

## Component 架構

```
Trigger Layer (Coordinator / ViewModel / View)
   │  analyticsService.track(.case(...))
   ▼
AnalyticsService protocol (DI singleton)
   │
   ▼
FirebaseAnalyticsServiceImpl
   │  Analytics.logEvent(name, parameters:)
   ▼
GA4
```

13 個新 case 加在 `AnalyticsEvent` enum，trigger 點散布於 onboarding（8 處）+ 5 個 P1 view 的 `onAppear`。**不引入新 protocol、不改 DI 結構。**

## 介面合約清單

新增 enum case（依 SPEC parameter 表逐字對齊）：

| Case | Parameters |
|------|-----------|
| `.onboardingDataSourcePrompted` | （無） |
| `.onboardingDataSourceSkipped` | （無） |
| `.onboardingDataSourceConnected(provider: String)` | `provider`(String) |
| `.onboardingGoalTypeSelected(targetType: String)` | `target_type`(String) |
| `.onboardingTargetRaceSet(targetType: String, raceId: String?, distanceKm: Double?)` | `target_type`(String), `race_id`(String?), `distance_km`(Double?) |
| `.onboardingScheduleSet(availableDays: Int)` | `available_days`(Int) |
| `.onboardingPlanGenerating(targetType: String)` | `target_type`(String) |
| `.weeklyPlanView(planId: String, weekOfTraining: Int)` | `plan_id`(String), `week_of_training`(Int) |
| `.workoutAnalysisView(workoutId: String, hasCoachNotes: Bool)` | `workout_id`(String), `has_coach_notes`(Bool) |
| `.weeklySummaryView(summaryId: String, weekOfTraining: Int)` | `summary_id`(String), `week_of_training`(Int) |
| `.planOverviewView(overviewId: String, targetType: String)` | `overview_id`(String), `target_type`(String) |
| `.racePredictionView(predictedTime: String, distanceKm: Double)` | `predicted_time`(String), `distance_km`(Double) |

`name` switch 全小寫 snake_case 對應 GA4 event name；`parameters` switch 嚴格按上表 key 名稱輸出（不傳 nil）。

## DB Schema 變更

無。

## 任務拆分

| # | 任務 | 角色 | Done Criteria |
|---|------|------|--------------|
| S01 | 擴 AnalyticsEvent enum + 13 個 trigger 接線 + AC tests + clean build | iOS Developer | 見下方 Done Criteria |

**單張 task — mechanical 工作不需拆 subtask。**

### S01 Done Criteria（每條可獨立驗證）

1. **AnalyticsEvent enum 擴展**：`AnalyticsEvent.swift` 新增 12 個 case（AC-P1-02..13 的事件——AC-P1-01 是結構性檢查，不單獨成 case）；每個 case 在 `name` switch 與 `parameters` switch 都有 mapping；`parameters` 的 key 嚴格匹配 SPEC 表（snake_case，nil 值省略）
2. **AC test stubs 全 PASS**：`HavitalTests/SpecCompliance/IosAnalyticsP1ACTests.swift` 中 13 個 test function 從 `XCTFail("NOT IMPLEMENTED")` 改為實作測試，使用 `MockAnalyticsService`（如不存在請新增）攔截 `track(_:)` 並斷言事件 name + parameter dict
3. **Trigger 點 8 處 onboarding**：
   - AC-P1-02：`.dataSource` step view onAppear（用 `.onAppear { coordinator.analyticsService.track(.onboardingDataSourcePrompted) }` 並用 session-level flag 去重）
   - AC-P1-03：`.dataSource` step skip flow 觸發點（找出既有的 skip / unbound 動作，在該 action 裡 track）
   - AC-P1-04：Garmin OAuth callback success path 與 Apple Health 授權成功 path（兩處），各帶對應 `provider`
   - AC-P1-05：`OnboardingFeatureViewModel` 的 `.goalType` 完成 callback（找到 commit goalType 的 method，在 navigationPath.append 之前 track）
   - AC-P1-06：`.raceEventList` 與 `.maintenanceRaceDistance` 完成 callback（race_run path + maintenance with race path）
   - AC-P1-07：`.trainingDays` 完成 callback，帶 `availableDays`
   - AC-P1-08：`.trainingOverview` view 的 `onAppear`（plan generating loading 畫面）
4. **Trigger 點 5 處 view onAppear**：
   - AC-P1-09：`TrainingPlanV2View.onAppear`，帶當前 plan_id + week_of_training；session-level 去重
   - AC-P1-10：workout detail view 的 onAppear（Developer 自行 grep `WorkoutDetailViewModelV2` 對應 view file 並接線）
   - AC-P1-11：`WeeklySummaryV2View.onAppear`
   - AC-P1-12：`PlanOverviewSheetV2.onAppear`
   - AC-P1-13：race prediction view onAppear（Developer grep `RacePrediction` / `predicted_time` 定位 view file）
5. **架構約束**：
   - Repository 不呼叫 `analyticsService.track()`（grep 應為 0 筆）
   - 所有 trigger 在 ViewModel / Coordinator / View 層
   - 走 `AnalyticsService` protocol，不直接 `Analytics.logEvent()`
6. **Clean build**：`xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` 0 errors
7. **xcodebuild test**：`xcodebuild test -project Havital.xcodeproj -scheme Havital -destination 'id=237D67B5-...' -parallel-testing-enabled NO -only-testing:HavitalTests/IosAnalyticsP1ACTests` 全 PASS（13 tests）
8. **Simulator 自驗**：Developer 用 simulator 跑一次 onboarding（race_run 路徑）+ 進入週課表 + 週回顧 + 訓練總覽，從 console log 觀察 `[Analytics]` log 行確認 13 個事件都有觸發（提供截圖或 log 片段）
9. **Simplify**：交付前跑 `/simplify`
10. **Completion Report**：明確列出每條 Done Criteria 的證據（檔案 line number + test 輸出 + simulator log）

### 必須從 FAIL 變 PASS 的 AC test：
`AC-IOS-ANALYTICS-P1-01, AC-IOS-ANALYTICS-P1-02, AC-IOS-ANALYTICS-P1-03, AC-IOS-ANALYTICS-P1-04, AC-IOS-ANALYTICS-P1-05, AC-IOS-ANALYTICS-P1-06, AC-IOS-ANALYTICS-P1-07, AC-IOS-ANALYTICS-P1-08, AC-IOS-ANALYTICS-P1-09, AC-IOS-ANALYTICS-P1-10, AC-IOS-ANALYTICS-P1-11, AC-IOS-ANALYTICS-P1-12, AC-IOS-ANALYTICS-P1-13`

## Risk Assessment

### 1. 不確定的技術點
- `workout_analysis_view` 與 `race_prediction_view` 對應的 SwiftUI View struct 名稱未明確 grep 定位 → Developer 第一步先 grep，如果找不到（race prediction 可能還是 component 不是獨立 view），標記為 [未實作 — view 尚未存在] 並請 Architect 決定 fallback
- onboarding 部分 step 的「完成 callback」可能藏在 `OnboardingFeatureViewModel` 的多個 method 中（`onboardingTargetSet` 既有就有 3 處 trigger 在不同 method），Developer 需逐個 path 接線，避免漏發

### 2. 替代方案與選擇理由
- **替代 A：用 GA4 自動 screen_view 取代手寫 view 事件** — 不選。GA4 自動事件無法帶業務 parameter（plan_id / target_type 等），漏斗 dimension 拆不出來
- **替代 B：把所有 trigger 寫進 Repository 統一發** — 不選。違反 iOS 架構規則 #4「Repository 不發事件」（CLAUDE.md）
- **本案：每個事件寫在最接近語義的 ViewModel / Coordinator / View 層** — 選此。對齊 P0 既有 pattern

### 3. 需要用戶確認的決策
（已由 PM 在前一輪拍板 5 題，無新增）

### 4. 最壞情況與修正成本
- **最壞**：Developer 漏接某個 trigger（例如 `.maintenanceRaceDistance` path 沒接 `onboarding_target_race_set`）→ GA4 漏斗看到「該 step 流失 100%」假象 → 1-2 天才會被察覺
- **修正成本**：補一個 trigger ~30 分鐘 + 驗證 1 小時 = 半天內收
- **mitigation**：AC test 用 mock service 直接斷言每個 path 的 trigger（race_run / maintenance / beginner 三條 path 各 fixture 一次），不靠 manual simulator
