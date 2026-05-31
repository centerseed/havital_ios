---
type: SPEC
id: SPEC-ios-analytics-p1
status: Under Review
parent: SPEC-analytics-event-tracking
ontology_entity: Analytics Event Tracking
created: 2026-05-05
updated: 2026-05-05
---

# Feature Spec: iOS P1 埋點實作（漏斗精細化 + 核心功能 view）

## 背景與動機

GA4 漏斗（2026-04-22 ~ 2026-05-05）顯示 onboarding 漏斗主要流失點：
- Step 1→2（`onboarding_start` → `onboarding_target_set`）：**19.2% 流失**（15 人）
- Step 2→3（`onboarding_target_set` → `onboarding_first_plan`）：**12.7% 流失**（8 人）

P0 onboarding 事件只到「進入 → 設目標 → 第一份課表」三段，**看不出哪個 step 流失**。本 spec 補齊 8 個細化 onboarding 事件 + 5 個核心功能 view 事件，定位流失原因並支撐 WS3 留存分析。

## 目標

把 iOS analytics P1（13 個事件）落地到 repo 內可驗收狀態：
1. **Onboarding 精細化**（8 事件）— 解決 P0 漏斗看不出 step 級流失的盲點
2. **核心功能 view**（5 事件）— 衡量「看週課表 / 看跑後分析 / 看週回顧 / 看訓練總覽 / 看完賽預測」對留存的影響

## Spec 相容性

已比對 spec：
- `SPEC-analytics-event-tracking`（主 SPEC）— P1 §4 已定義 5 個 view 事件，本 spec 直接對齊；onboarding 精細化 8 事件為新增，主 SPEC §P1 §4 同步補 onboarding 精細化子節
- `SPEC-ios-analytics-p0`（同層 sub-spec）— P0 既有 `onboarding_start` / `onboarding_target_set` / `onboarding_complete` / `onboarding_garmin_connect` / `onboarding_garmin_complete` 不動；新事件並存
- `SPEC-onboarding-delayed-data-source-binding` — onboarding 已支援 `data_source=unbound` 直接完成；本 spec `onboarding_data_source_*` 三事件範圍**僅限 onboarding 內**，post-onboarding reminder 不在 scope

衝突：無

## 現有基礎設施

- `Core/Analytics/AnalyticsEvent.swift` — 11 個 case 已上 prod，新增 13 個 case 沿用同 pattern（type-safe enum + `name` / `parameters` switch）
- `Core/Analytics/AnalyticsService.swift` — `track(_:)` 入口
- `Features/Onboarding/Presentation/Coordinators/OnboardingCoordinator.swift` — `Step` enum 含 `.intro / .dataSource / .heartRateZone / .backfillPrompt / .personalBest / .weeklyDistance / .goalType / .raceSetup / .raceEventList / .startStage / .methodologySelection / .trainingWeeksSetup / .maintenanceRaceDistance / .trainingDays / .trainingOverview / .dataSync`，nav 機制為 `navigationPath.append(step)`

## 需求

### P1 — Onboarding 漏斗精細化（8 事件）

#### AC-IOS-ANALYTICS-P1-01: AnalyticsEvent enum 擴 13 個 case

Given iOS app 編譯，
When 任何模組需要發送本 spec 的新事件，
Then `AnalyticsEvent` enum 包含對應 13 個新 case，且 `name` / `parameters` switch 已實作。

**規格**：
- 新 case 命名與 `name` switch 對應 GA4 event name（snake_case）
- `parameters` switch 嚴格匹配下方各 AC 的 parameter 表
- 不直接呼叫 `Analytics.logEvent()`；統一走 `AnalyticsService.track(_:)`

#### AC-IOS-ANALYTICS-P1-02: onboarding_data_source_prompted

Given 新用戶進入 onboarding，
When 進入 `.dataSource` step（畫面 `onAppear`），
Then 發送 `onboarding_data_source_prompted` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| (無) | — | — | 無參數 |

**重複觸發限制**：同一 onboarding session 內只發一次，避免 step 反覆進出造成重複計數。

#### AC-IOS-ANALYTICS-P1-03: onboarding_data_source_skipped

Given 用戶在 `.dataSource` step，
When 用戶選擇「skip / 暫不綁定 / unbound」流程離開 step，
Then 發送 `onboarding_data_source_skipped` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| (無) | — | — | 無參數 |

#### AC-IOS-ANALYTICS-P1-04: onboarding_data_source_connected

Given 用戶在 `.dataSource` step，
When 用戶在 onboarding 內成功綁定 Garmin OAuth 或授權 Apple Health，
Then 發送 `onboarding_data_source_connected` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `provider` | String | Yes | `"garmin"` / `"apple_health"` |

**注意**：與 P0 既有 `onboarding_garmin_connect`（Garmin OAuth 結果追蹤）並存，語義不同。本事件聚焦「step 級」綁定成功；P0 事件聚焦 OAuth 成功率。

#### AC-IOS-ANALYTICS-P1-05: onboarding_goal_type_selected

Given 用戶進入 `.goalType` step，
When 用戶選定目標類型並離開 `.goalType` step（按 Next 進入下一步時），
Then 發送 `onboarding_goal_type_selected` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `target_type` | String | Yes | `"race_run"` / `"maintenance"` / `"beginner"` |

#### AC-IOS-ANALYTICS-P1-06: onboarding_target_race_set

Given 用戶完成賽事/距離設定（`race_run` 走 `.raceSetup` → `.raceEventList`，`maintenance` 走 `.maintenanceRaceDistance`），
When 用戶確認賽事/距離選擇，離開該 step，
Then 發送 `onboarding_target_race_set` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `target_type` | String | Yes | 與 `onboarding_goal_type_selected` 相同 |
| `race_id` | String | No | race_run 才有 |
| `distance_km` | Double | No | race_run / maintenance 才有 |

**Beginner 路徑不發此事件**（無賽事設定 step）。

#### AC-IOS-ANALYTICS-P1-07: onboarding_schedule_set

Given 用戶進入 `.trainingDays` step，
When 用戶選定每週可訓練天數並離開 step，
Then 發送 `onboarding_schedule_set` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `available_days` | Int | Yes | 1–7，對應 `OnboardingCoordinator.availableDays` |

#### AC-IOS-ANALYTICS-P1-08: onboarding_plan_generating

Given 用戶完成所有設定 step，
When 進入 `.trainingOverview`（plan generation loading 畫面 `onAppear`），
Then 發送 `onboarding_plan_generating` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `target_type` | String | Yes | `"race_run"` / `"maintenance"` / `"beginner"` |

**用途**：定位「設定全完成但生成 API 失敗」流失點。

### P1 — 核心功能 view（5 事件）

#### AC-IOS-ANALYTICS-P1-09: weekly_plan_view

Given 用戶導航至週課表畫面，
When `TrainingPlanV2View`（或對應的 weekly plan view container）`onAppear` 且資料已載入，
Then 發送 `weekly_plan_view` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `plan_id` | String | Yes | 當前週課表 ID（取自 `WeeklyPlanV2.id` 或同義欄位） |
| `week_of_training` | Int | Yes | 訓練週次 |

**重複觸發處理**：同一 `plan_id` + `week_of_training` 組合在單次前景 session 內只發一次。

#### AC-IOS-ANALYTICS-P1-10: workout_analysis_view

Given 用戶查看跑後分析（workout detail），
When workout detail view `onAppear` 且資料已載入，
Then 發送 `workout_analysis_view` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `workout_id` | String | Yes | workout doc ID |
| `has_coach_notes` | Bool | Yes | 是否有 LLM coach notes 欄位 |

#### AC-IOS-ANALYTICS-P1-11: weekly_summary_view

Given 用戶查看週回顧，
When `WeeklySummaryV2View` `onAppear` 且 summary 資料已載入，
Then 發送 `weekly_summary_view` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `summary_id` | String | Yes | weekly summary doc ID |
| `week_of_training` | Int | Yes | 訓練週次 |

#### AC-IOS-ANALYTICS-P1-12: plan_overview_view

Given 用戶查看訓練總覽，
When `PlanOverviewSheetV2`（或對應 plan overview entry view）`onAppear` 且資料已載入，
Then 發送 `plan_overview_view` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `overview_id` | String | Yes | `PlanOverviewV2.id` 或同義欄位 |
| `target_type` | String | Yes | `"race_run"` / `"maintenance"` / `"beginner"` |

#### AC-IOS-ANALYTICS-P1-13: race_prediction_view

Given 用戶查看完賽預測，
When race prediction view `onAppear` 且預測資料已載入（非 nil / 非 loading），
Then 發送 `race_prediction_view` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `predicted_time` | String | Yes | ISO 8601 duration 或 `HH:MM:SS` 字串（與 backend 一致） |
| `distance_km` | Double | Yes | 預測距離 |

## 明確不包含

- **GA4 dashboard / Funnel Exploration 配置驗收** — 屬外部 GA4 UI 邊界，非 repo 內驗收，延後到 WS3
- **Post-onboarding data source reminder 事件** — 不在本 spec scope
- **既有 P0 事件 (`onboarding_start` / `onboarding_target_set` / `onboarding_complete` / `onboarding_garmin_*` / `onboarding_first_plan`)** 不動
- **A/B testing variant tracking**

## 技術約束（給 Architect / Developer 參考）

1. **不阻塞主流程** — 事件發送 fire-and-forget
2. **Repository 不發事件** — 所有 trigger 點在 ViewModel / Coordinator / View 層
3. **去重機制** — onboarding 事件每 session 一次；view 事件用 `plan_id+week` / `workout_id` / `summary_id+week` / `overview_id` 等 key 去重
4. **AnalyticsService 走 DI** — 透過 `analyticsService` computed property 或 `@Injected` 取得，不寫死
5. **i18n 不適用** — 所有 parameter value 是穩定 ASCII identifier（`race_run` / `garmin` 等），不翻譯

## 事件總覽

| # | Event Name | Trigger 位置 | AC ID |
|---|-----------|------------|-------|
| 1 | `onboarding_data_source_prompted` | `.dataSource` step onAppear | P1-02 |
| 2 | `onboarding_data_source_skipped` | `.dataSource` step skip flow | P1-03 |
| 3 | `onboarding_data_source_connected` | Garmin OAuth / Apple Health 授權成功 | P1-04 |
| 4 | `onboarding_goal_type_selected` | `.goalType` step 完成 | P1-05 |
| 5 | `onboarding_target_race_set` | `.raceEventList` / `.maintenanceRaceDistance` 完成 | P1-06 |
| 6 | `onboarding_schedule_set` | `.trainingDays` step 完成 | P1-07 |
| 7 | `onboarding_plan_generating` | `.trainingOverview` 進入 loading | P1-08 |
| 8 | `weekly_plan_view` | weekly plan view onAppear | P1-09 |
| 9 | `workout_analysis_view` | workout detail onAppear | P1-10 |
| 10 | `weekly_summary_view` | `WeeklySummaryV2View` onAppear | P1-11 |
| 11 | `plan_overview_view` | `PlanOverviewSheetV2` onAppear | P1-12 |
| 12 | `race_prediction_view` | race prediction view onAppear | P1-13 |

> 註：AC-P1-01 為 enum 結構性 AC，不對應單一事件。

## 開放問題

1. `race_prediction_view` 在現有 codebase 中對應的 view file 名稱待 Developer 階段定位（可能是 `RacePredictionView` / `PredictionCardView` / dashboard 中的 component）
2. `workout_analysis_view` 對應的 detail view file 待 Developer 階段定位（`WorkoutDetailViewModelV2` 對應的 view）
