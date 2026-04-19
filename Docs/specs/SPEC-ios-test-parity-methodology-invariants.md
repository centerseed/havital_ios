---
type: SPEC
id: SPEC-ios-test-parity-methodology-invariants
status: Draft
ontology_entity: ios-test-parity-methodology-invariants
created: 2026-04-18
updated: 2026-04-18
---

# Feature Spec: iOS Test Parity — Methodology Invariants & LLM/non-LLM Split

## 背景與動機

目前 iOS App 的測試覆蓋度落後 backend（`cloud/api_service/tests/` 676 檔、明確分 `unit / integration / llm_tests / spec_compliance / smoke`）。

iOS 端實際現況：

- `HavitalTests/` ~90 檔，以單元為主；`Integration/` 6 檔，僅 V1 路徑
- `SpecCompliance/` 只有 1 檔（workout-upload-error-noise-filtering），幾乎空殼
- `Fixtures/WeeklyPlan/` 只有 4 份 fixture；`PlanOverview/` 3 份；`WeeklySummary/` 2 份
- `MethodologyConstraintTests` 只覆蓋 4 個 case（paceriz base/peak、polarized build、complete_10k conversion），**hansons / norwegian 完全缺席**
- **無 LLM / non-LLM 測試分流**，全部 fixture-based 或全部打真 API 沒有中間層
- `HavitalUITests/E2E` 宣告 12 case 矩陣但只實作 race_run 6 case，且 `PlanVerificationHelper` 只斷言 target_type / methodology / total_weeks / session count，**沒有方法論合理性斷言**
- `.maestro/flows/` 承擔主要 UI 驗證責任，但 Maestro 語法無法做課表結構性檢查

此 spec 的目標：**把 iOS 測試覆蓋對齊到後端嚴謹度**，讓訓練總覽（PlanOverview）與週回顧（WeeklySummary）可交叉驗證所有方法論產出**合理課表**，並明確分離 LLM / non-LLM 測試，讓 Maestro 退位為人工補測角色。

## 範圍

- 新建 `HavitalTests/SpecCompliance/TrainingPlan/` 類別，承載方法論 invariant AC tests
- 擴充 `HavitalTests/.../Fixtures/` 到「方法論 × 階段 × 目標類型」矩陣
- 新建獨立測試 target `HavitalLLMTests`，承載會呼叫真實 LLM / dev API 的回歸測試
- 擴充 `HavitalUITests/E2E` 的 PlanVerificationHelper，共用 invariant 規則
- 補完 E2E XCUITest 12-case 矩陣（beginner + maintenance 剩餘 case）
- 建立「方法論 invariant 規則集」作為 SSOT，三層（SpecCompliance / LLM / E2E）共用
- 把 `.maestro/flows/` 中被 SpecCompliance / E2E 取代的項目標記為人工補測或淘汰

## 明確不包含

- 修改任何 production 邏輯（只補測試與 fixture）
- 修改 backend 行為（fixture 直接 freeze 當前 prod 產出）
- 新建 UI Snapshot testing（改日再議）
- Maestro 腳本重寫（只做清單化退位）
- Android / Flutter 對齊（本 spec 僅限 iOS）

## 用語定義

| 名詞 | 定義 |
|------|------|
| 方法論 | `paceriz`, `hansons`, `norwegian`, `polarized`（race_run）；`balanced_fitness`, `aerobic_endurance`（beginner / maintenance） |
| 階段 | `conversion`, `base`, `build`, `peak`, `taper`（各方法論取子集） |
| 訓練總覽 | PlanOverviewV2 實體，含 methodology、targetType、totalWeeks、trainingStages、milestones |
| 週課表 | WeeklyPlanV2 實體，含 7 個 DayDetail、intensityTotalMinutes |
| 週回顧 | WeeklySummaryV2 實體，含 planContext、trainingAnalysis、nextWeekAdjustments |
| Invariant | 「無論 LLM 如何變化，此規則必永遠成立」的課表合理性約束 |
| non-LLM test | 純 fixture-based、可在 iOS unit test target 離線跑、CI 每 PR 跑 |
| LLM test | 會打真實 backend / LLM 產出，在 `HavitalLLMTests` target，nightly 或 pre-release 跑 |

## 需求

### Group A: 方法論 Invariant 規則集（SSOT）

#### AC-IOS-TESTPARITY-INV-01: 每方法論必須定義可編譯的 invariant 規則集

Given 我要驗證任意方法論產出的 WeeklyPlanV2，
When 測試層呼叫 `MethodologyInvariants.rules(for: methodologyId, phase: stageId)`，
Then 系統必須回傳一組明確的 positive + negative 斷言規則（至少包含：允許的 runType、禁止的 runType、intensity 分佈下界、週跑量合理範圍），且規則集放在 `HavitalTests/Shared/MethodologyInvariants.swift`（或等效路徑）供 SpecCompliance / LLM / E2E 三層共用。

#### AC-IOS-TESTPARITY-INV-02: Paceriz invariant 覆蓋 base / build / peak / taper

Given Paceriz 的週課表 fixture（race_run），
When 驗證階段是 `base` / `build` / `peak` / `taper` 其中之一，
Then 必須成立：
- `base`: 含 tempo，禁止 interval / VO2max；easy 比例 ≥ 70%
- `build`: 含 tempo + threshold，interval 可選；medium 比例 > 0
- `peak`: 必含 interval + threshold；接近賽事配速 session 至少 1 次
- `taper`: 總跑量相對前週 ≤ 70%；無新的高強度刺激

#### AC-IOS-TESTPARITY-INV-03: Hansons invariant（累積疲勞法）

Given Hansons 方法論的週課表 fixture，
When 驗證週課表，
Then 必須成立：
- 長跑日單次距離 ≤ 週跑量的 30%（累積疲勞原則）
- 每週含 1 次 tempo / threshold 與 1 次 speed 或 strength，長跑日後 24h 內不得安排高強度

#### AC-IOS-TESTPARITY-INV-04: Norwegian invariant（乳酸閾值）

Given Norwegian 方法論的週課表 fixture，
When 驗證週課表，
Then 必須成立：
- 必含至少一次 `norwegian4x4` 或 `cruiseIntervals` 類型 session
- threshold + interval 合計占總 session ≥ 2 次/週

#### AC-IOS-TESTPARITY-INV-05: Polarized invariant（80/20）

Given Polarized 方法論的週課表 fixture，
When 驗證週課表，
Then 必須成立：
- `intensityTotalMinutes.medium == 0`
- 無 `tempo` / `threshold` runType
- `intensityTotalMinutes.low` / `(low + high)` ≥ 0.78

#### AC-IOS-TESTPARITY-INV-06: 通用合理性 invariant（所有方法論）

Given 任意方法論的週課表 fixture，
When 驗證週課表，
Then 必須成立：
- 所有 run 配速在 2:30/km – 9:00/km 之間（除 recovery 可到 9:30）
- 長跑日與用戶設定的 `longRunDay` 一致
- 不得連續兩日高強度（interval / threshold / tempo）
- 訓練天數與用戶設定的 `trainingDays` 一致（休息日 session 為 nil）

### Group G: Structural Invariants（對齊 backend weekly_plan_validator + base_test）

此組規則來自後端 SSOT：
- `cloud/api_service/domains/training_plan/weekly_plan_validator.py`
- `cloud/api_service/tests/llm_tests/v2/weekly_plan_llm/base_test.py`
- `cloud/api_service/domains/training_plan/app_contract_validators.py`

目標：iOS MethodologyInvariants 的 structural 檢查結果必須與後端 validator 一致（同一份課表在 backend PASS 時 iOS 也 PASS；backend FAIL 時 iOS 也 FAIL）。

#### AC-IOS-TESTPARITY-STRUCT-01: 週課表必須正好 7 天、day_index 1–7 不重複

Given 任意 WeeklyPlanV2 fixture，
When `MethodologyInvariants.validateStructure(plan)` 執行，
Then `plan.days.count == 7`、day_index 涵蓋 1–7 且無重複，違反時產生 `STRUCT-01.*` ruleId 的 violation。

#### AC-IOS-TESTPARITY-STRUCT-02: 至少 1 天休息（category == rest 或 session == nil）

Given 任意週課表，
When 驗證，
Then 至少一天沒有 session（rest day），否則產出 `STRUCT-02.rest_day_required`。

#### AC-IOS-TESTPARITY-STRUCT-03: 非休息日必有 primary activity

Given 任意週課表，
When 某 day 的 `category != rest`，
Then 該 day 的 `session.primary` 必須存在，否則 `STRUCT-03.non_rest_has_primary`。

#### AC-IOS-TESTPARITY-STRUCT-04: Run 必含 distance_km / duration_minutes / segments / interval 其一

Given 任意 run day，
When 驗證其 RunActivity，
Then 必須至少一項非 nil，否則 `STRUCT-04.run_must_have_workload`。

#### AC-IOS-TESTPARITY-STRUCT-05: 非 interval / fartlek 的 run 必須有 heart_rate_range

Given 某 day 的 runType 不屬於 {interval, fartlek}，
When 驗證，
Then `heartRateRange` 不可為 nil，否則 `STRUCT-05.hr_range_required`。

#### AC-IOS-TESTPARITY-STRUCT-06: IntervalBlock 必須 repeats > 0 且含 work_pace / work_distance_km / work_distance_m 其一

Given 含 interval 的 run day，
When 驗證，
Then `interval.repeats > 0`；`work_pace` / `work_distance_km` / `work_distance_m` 至少一項非 nil，否則 `STRUCT-06.interval_incomplete`。

#### AC-IOS-TESTPARITY-STRUCT-07: IntensityTotalMinutes 必須存在且 low/medium/high 為非負整數

Given 任意週課表，
When 驗證，
Then `intensityTotalMinutes` 不可 nil；三欄皆 ≥ 0；違反時 `STRUCT-07.intensity_invalid`。

#### AC-IOS-TESTPARITY-STRUCT-08: 每週 hard sessions 數不得超過上限

Given 任意週課表與 `maxHardSessions`（預設 2），
When 統計 runType 或 interval.variant 落在 HARD_TYPES 集合的 day 數，
Then 不得超過 `maxHardSessions`；否則 `STRUCT-08.too_many_hard_sessions`。
HARD_TYPES 必須與後端 `WeeklyPlanValidator.HARD_TYPES` 一致：`{interval, short_interval, long_interval, tempo, threshold, fartlek, norwegian_4x4, yasso_800, mile_repeats, hill_repeats, cruise_intervals, race_pace, strides}`。

#### AC-IOS-TESTPARITY-STRUCT-09: Conversion / Peak / Taper 期不得出現 supplementary strength

Given 週課表處於 `conversion` / `peak` / `taper` 階段（由 config 傳入或 fixture metadata 標記），
When 驗證，
Then 所有 day 的 `supplementary` 不得含 `strength`；違反 `STRUCT-09.no_strength_in_gated_stage`。

#### AC-IOS-TESTPARITY-STRUCT-10: iOS invariant 結果必須與 backend validator 在跨驗場景下一致

Given 同一份 weekly plan JSON，
When 同時跑 iOS `MethodologyInvariants.validate(...)` 與 backend `weekly_plan_validator.validate(...)`，
Then 兩邊 violation 集合必須同方向（backend pass 則 iOS 無 STRUCT 層 violation；backend fail 則 iOS 至少一條 STRUCT-* violation），此 AC 由 fixture cross-validation test 守衛。

### Group B: non-LLM Fixture 矩陣擴充

#### AC-IOS-TESTPARITY-FIXT-01: PlanOverview fixture 矩陣必須覆蓋所有方法論 × 目標類型

Given `HavitalTests/TrainingPlan/Unit/APISchema/Fixtures/PlanOverview/`，
When 跑 SpecCompliance 測試，
Then 以下 fixture 必須存在且 decode 成功：
- `race_run_paceriz.json`（已存在）
- `race_run_hansons.json`（新增）
- `race_run_norwegian.json`（新增）
- `race_run_polarized.json`（新增）
- `beginner_10k.json`（已存在）
- `maintenance_aerobic.json`（已存在）
- `maintenance_paceriz.json`（新增）

#### AC-IOS-TESTPARITY-FIXT-02: WeeklyPlan fixture 矩陣必須覆蓋方法論 × 關鍵階段

Given `Fixtures/WeeklyPlan/`，
When 跑 SpecCompliance 測試，
Then 以下矩陣 fixture 必須存在（至少 13 份）：
- paceriz: base（已）、build（新）、peak（已）、taper（新）
- hansons: base（新）、peak（新）、taper（新）
- norwegian: base（新）、peak（新）
- polarized: base（新）、build（已）、peak（新）
- beginner: conversion（已有 complete_10k）、base（新）

#### AC-IOS-TESTPARITY-FIXT-03: WeeklySummary fixture 矩陣必須覆蓋方法論 × 週類型

Given `Fixtures/WeeklySummary/`，
When 跑 SpecCompliance 測試，
Then 以下 fixture 必須存在：
- `paceriz_normal_week.json`、`paceriz_taper_week.json`、`paceriz_final_week.json`
- `hansons_normal_week.json`
- `norwegian_normal_week.json`
- `polarized_normal_week.json`
- `beginner_normal_week.json`
- 保留現有 `minimal_summary.json` / `full_summary.json` 作為 schema 邊界測試

#### AC-IOS-TESTPARITY-FIXT-04: Fixture 產出來源必須可追溯

Given 每份新增 fixture，
When 有人需要重新產生或更新，
Then 在 `Fixtures/README.md` 明確記錄每份 fixture 對應的 `user_uid`、`overview_id`、`raw API endpoint`、`擷取日期`，且 fixture 本身透過去敏後的真實 prod / dev API response 而非手寫。

### Group C: SpecCompliance 測試層（non-LLM）

#### AC-IOS-TESTPARITY-SC-01: 每條 Invariant AC 必須有對應 XCTest function

Given `HavitalTests/SpecCompliance/TrainingPlan/`，
When 執行 `xcodebuild test -only-testing:HavitalTests/SpecComplianceTrainingPlan...`，
Then 以下 test file 必須存在：
- `PlanOverviewMethodologyACTests.swift`（對應 AC-IOS-TESTPARITY-INV-01, FIXT-01）
- `WeeklyPlanMethodologyACTests.swift`（對應 INV-02 到 INV-06）
- `WeeklySummaryMethodologyACTests.swift`（對應 FIXT-03）
每條 AC 至少一個 function，function 名稱含 AC ID，docstring 引用 SPEC 原文。

#### AC-IOS-TESTPARITY-SC-02: SpecCompliance 測試必須零外部依賴

Given SpecCompliance 測試執行時，
When 測試進行中，
Then 不得發起任何 HTTP / Firebase / HealthKit 呼叫；所有資料來自本機 fixture 檔案；runtime < 10s。

#### AC-IOS-TESTPARITY-SC-03: SpecCompliance 測試必須進 default scheme CI

Given `Havital.xctestplan` 或對應 scheme，
When CI 每 PR 執行 build gate，
Then `SpecCompliance/TrainingPlan/` 中所有 test 被包含在預設測試集合，PR 不 pass 此集合不得 merge。

### Group D: LLM 測試層（新 target）

#### AC-IOS-TESTPARITY-LLM-01: 建立 HavitalLLMTests target

Given `Havital.xcodeproj`，
When 開發者在本機跑 `xcodebuild test -scheme HavitalLLMTests`，
Then 此 target 必須存在、可獨立 build、與 `HavitalTests` 完全隔離（不同 bundle），且預設 CI PR 不跑此 target。

#### AC-IOS-TESTPARITY-LLM-02: LLM test 必須重用 MethodologyInvariants 規則集

Given LLM test 執行 onboarding → 產生 plan → pull weekly →，
When 驗證 API 回傳的課表，
Then 必須呼叫 `MethodologyInvariants.validate(weeklyPlan, methodology, phase)` 做斷言，不得手寫獨立斷言（避免規則漂移）。

#### AC-IOS-TESTPARITY-LLM-03: LLM test 必須覆蓋 4 種方法論的真實產出

Given `HavitalLLMTests/`，
When 執行完整 LLM regression，
Then 至少 4 個 test case 各自對應 paceriz / hansons / norwegian / polarized，打 dev 後端完整跑 `onboarding → create plan → get overview → get weekly(W1) → get weekly(W mid) → get summary`，每步驗 MethodologyInvariants。

#### AC-IOS-TESTPARITY-LLM-04: LLM test 失敗分類必須明確

Given LLM test 失敗時，
When 產出報告，
Then 必須分類為以下三者之一：`backend-prompt-regression`（backend 產出違反 invariant）/ `ios-decoding-gap`（iOS Mapper 漏讀欄位）/ `infra-flake`（HTTP / auth 失敗），不得只說 "LLM test failed"。

### Group E: E2E XCUITest 補齊與升級

#### AC-IOS-TESTPARITY-E2E-01: 12-case 矩陣必須全部實作

Given `HavitalUITests/E2E/TestMatrix.allConfigs`（12 項），
When 執行 `xcodebuild test -only-testing:HavitalUITests/E2E`，
Then 12 個 XCUITest case 全部存在且可執行（不得只有 6 個 race_run case）。

#### AC-IOS-TESTPARITY-E2E-02: PlanVerificationHelper 必須呼叫 MethodologyInvariants

Given `PlanVerificationHelper` 在拉完 plan overview / weekly plan 後，
When 做驗證，
Then 必須呼叫 `MethodologyInvariants.validate(...)`，且斷言輸入的 `longRunDay` / `trainingDays` 與 user config 一致。

### Group H: UI Render Compliance（主要守線）

設計原則：**「既然要守當然就是走路徑最長的那一條」**。
- L1（data fixture invariants）與 L2（ViewModel mock）是內部保護，不是 test parity 的最終 gate。
- **L3 XCUITest + fixture injection 是交付守線**：真實啟動 App、走真實 SwiftUI render、斷言畫面上確實看得到 invariants 對應的元素。
- 一條 invariant 必對應至少一條 UI 斷言；光 data 過 invariant 但 UI 不顯示 → 算失敗。

#### AC-IOS-TESTPARITY-UI-01: UITestMethodologyHarness 能透過 launch arg 注入 fixture

Given App 以 `-ui_testing_methodology_fixture` launch arg + `UITEST_METHODOLOGY_FIXTURE=<fixture_name>` env var 啟動，
When App 啟動完成，
Then `UITestMethodologyHarness` 必須把 `TrainingPlanV2Repository` / `TargetRepository` / `PlanOverviewRepository` 等依賴替換為 fixture 驅動版本，讓 UI 直接渲染對應 fixture 的資料；App 不得打任何真實 API。

#### AC-IOS-TESTPARITY-UI-02: PlanOverview 畫面必須顯示方法論核心資訊

Given fixture 為 `race_run_<methodology>.json`（任一方法論），
When App 導航到訓練總覽畫面，
Then 畫面上必須同時出現：方法論名稱、philosophy 描述、intensity_description（如 "75% 低強度..."）、training_stages 每階段的 stage_name 與週數範圍、至少一個 milestone title；以上缺一條算 UI 呈現失敗。

#### AC-IOS-TESTPARITY-UI-03: Weekly Plan 畫面必須顯示每日訓練類型與配速/心率

Given fixture 為 `<methodology>_<phase>_week.json`，
When App 導航到週課表頁、展開每日訓練卡片，
Then 每個非休息日必須在 UI 看到：訓練類型中文標籤（如 "節奏跑"、"間歇"、"輕鬆跑"）、配速（`m:ss/km` 格式）或心率區間、週總跑量數字；invariant 說該方法論/階段必有 interval → UI 必須看到對應間歇文字（含組數 repeats）；invariant 說 medium=0 → UI 不得顯示任何 tempo/threshold 文案。

#### AC-IOS-TESTPARITY-UI-04: Weekly Summary 畫面必須顯示 completion / analysis / adjustments

Given fixture 為 `<methodology>_<week_type>_summary.json`，
When App 導航到週回顧頁，
Then 畫面必須呈現：training_completion percentage、training_analysis 的 pace/intensity 描述、weekly_highlights 至少 1 條、next_week_adjustments 至少 1 條；race_run summary 必須顯示 upcoming_race_evaluation 的 days_remaining；final week summary 必須顯示 final_training_review 區塊。

#### AC-IOS-TESTPARITY-UI-05: Methodology × Phase XCUITest 矩陣完整

Given 每組 `(methodology, phase)` fixture，
When 跑 `HavitalUITests/MethodologyRender/`，
Then 至少覆蓋以下組合：paceriz base / build / peak / taper、hansons base / peak、norwegian base / peak、polarized base / peak、beginner conversion、maintenance base — 總計 ≥ 11 支 XCUITest case，每支一 fixture × 一畫面組合（overview / weekly / summary 各自選）。

#### AC-IOS-TESTPARITY-UI-06: UI 斷言必須呼叫 invariants SSOT

Given XCUITest 在斷言 UI 可見元素時，
When 要驗證「該方法論該階段應該出現什麼」，
Then 不得在 test 內 hardcode 期望值；必須由 `MethodologyInvariants` 或新輔助類 `UIAssertionGuide.expectedVisibleElements(methodology:phase:fixture:)` 產生期望清單；invariant 改了 → UI test 自動跟著改，不會 drift。

#### AC-IOS-TESTPARITY-UI-07: 任一 UI 斷言失敗必須截圖保留

Given XCUITest 執行失敗時，
When 產出報告，
Then `XCTAttachment` 必須附上 failure 當下整頁截圖與 element tree dump（xcuitest 內建），方便人工複驗「是 App bug 還是 test script bug」。

### Group F: Maestro 退位與文件

#### AC-IOS-TESTPARITY-MAESTRO-01: 被取代的 Maestro flow 必須標記或移除

Given `.maestro/flows/` 中的方法論驗證 flow（`regression-race-*-suite.yaml`, `weekly-plan-quality-checks.yaml`, `overview-weekly-consistency.yaml`），
When 對應的 SpecCompliance + E2E 測試完成並 PASS，
Then 該 Maestro flow 必須在檔案頂部加 YAML comment 註明 `# SUPERSEDED BY: SpecCompliance + E2E XCUITest`，或搬到 `.maestro/manual-supplement/`，不得留在 CI 自動跑清單。

#### AC-IOS-TESTPARITY-MAESTRO-02: 保留的 Maestro flow 必須有明確保留理由

Given 保留在 `.maestro/flows/` 的 flow（例如 `iap-*`, `demo-login*`, `onboarding-layout-consistency.yaml`），
When 檢查保留原因，
Then README.md 或 flow 頂部必須標明「XCUITest 無法覆蓋 / IAP StoreKit / 推播 / 人工視覺」其中一種合理原因。

#### AC-IOS-TESTPARITY-DOC-01: 測試分層文件必須存在

Given 任何新進 developer，
When 查看 `Havital/Docs/reference/`（或對應路徑），
Then 必須有一份 `testing-layers.md`，說明四層（HavitalTests / HavitalLLMTests / HavitalUITests / Maestro）的職責邊界、執行時機、CI 行為、跨層共用 Invariants 規則的使用方式。

## Done Criteria（交付前必須全部 PASS）

- 以上 Group A–H 的所有 AC 對應的 test function 都從 NOT IMPLEMENTED 變 PASS
- `xcodebuild test -scheme Havital -only-testing:HavitalTests/SpecCompliance` 零 failure（L1 data 守線）
- **`xcodebuild test -scheme Havital -only-testing:HavitalUITests/MethodologyRender` 零 failure（L3 UI 主守線）**
- `xcodebuild test -scheme HavitalLLMTests`（手動觸發）zero failure，且至少跑過一次完整 4 方法論 regression
- Fixture 矩陣完整（PlanOverview ≥ 7 份、WeeklyPlan ≥ 13 份、WeeklySummary ≥ 7 份），且 `Fixtures/README.md` 記錄來源
- `MethodologyInvariants.swift` 建立，L1 / L3 XCUITest / LLM 三層共用同一套 invariants
- `UITestMethodologyHarness` 可透過 launch arg + env var 注入任一 fixture，App 啟動後 UI 顯示 fixture 資料
- `Havital/Docs/reference/testing-layers.md` 完成，明確標示 L3 是交付守線
- Maestro flow 該退位的已加 SUPERSEDED 標記，保留的有明確理由
- PLAN Resume Point 標示 done，journal 寫入
