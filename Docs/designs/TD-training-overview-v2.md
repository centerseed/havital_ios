---
type: TD
id: TD-training-overview-v2
status: under_review
created: 2026-05-22
owner: agent:tpm
repo: apps/ios/Havital
---

# Technical Design: Training Overview v2（合併訓練總覽 + 訓練進度，單頁滾動）

## Scope（已與用戶確認）

- **合併對象 = 訓練總覽（`TrainingPlanOverviewDetailView`）+ 訓練進度（`TrainingProgressView`）。**
  砍掉 `TrainingProgressView`，把其「每週清單 + 課表/週回顧 入口」併進新總覽的 `PhaseRoadmap`。
- **訓練紀錄分頁（`TrainingRecordView`）保留不動**（本次不併）。
- **本次只做 L1 總覽**；L2 體能趨勢詳細頁（`FitnessTrajectoryScreen`）**不做**（趨勢入口先隱藏或停用）。
- 來源設計：Claude Design bundle `Training Overview v2.html` → `OverviewScreenB`（plan-overview.jsx）。

## Investigation Report（A1 carry-over + 資料盤點）

設計檔（已讀）
- `Training Overview v2.html` — 只載 `plan-overview.jsx`；渲染 `OverviewScreenB`(L1) + `FitnessTrajectoryScreen`(L2)；模式 race/starter/maintain。**未載入 `training-log.jsx`** → 訓練紀錄清單重設計與本次無關。
- `OverviewScreenB` 區塊順序：HERO（漸層底；倒數天數[race]；「●階段·第N/M週」chip）→ 數據卡[race]（距離/目標時間/目標配速 + `FitnessGapGauge`→L2）→ `PhaseRoadmap`（每階段展開＝該期所有週 + 每週「課表/週回顧」icon + 賽事 pin + 週跑量 + key workouts）→ 方法論+策略（合併一卡）→ 里程碑。
- `chat3:865` 意圖：「砍掉訓練進度，把每週清單 + 課表/週回顧 icon 併進 PhaseRoadmap」；`chat3:72/96`：砍總覽原雙 tab 改單頁。

現有 iOS（已讀）
- 訓練總覽 = `Havital/Views/Training/TrainingPlanOverviewDetailView.swift`（首頁「⋯」選單 → 訓練總覽）。
- 訓練進度 = `Havital/Views/Training/TrainingProgressView.swift`（`trainingStageDescription` 階段 + `weeklyDetailsList(startWeek...endWeek)` 每週 + `selectedWeekForSummary` 週回顧 sheet）。
- 資料模型 = `Havital/Features/TrainingPlanV2/Domain/Entities/PlanOverviewV2.swift`：
  - `trainingStages: [TrainingStageV2]`（stageName / weekStart / weekEnd / trainingFocus / targetWeeklyKmRange(+Display) / intensityRatio / **keyWorkouts**）
  - `milestones: [MilestoneV2]`、`methodologyOverview`、`approachSummary`、`targetEvaluate`
  - race：`raceDate`/`distanceKm(+Display/unit)`/`targetPace`/`targetTime`/`targetName`/`isMainRace`
  - `totalWeeks`、`startFromStage`、`createdAt`
- 週資料：`TrainingProgressView` 已用 `viewModel.weeklySummaries`（實際）+ `weeklyPlan`/overview 算每週；週回顧 = `viewModel.weeklySummary`（sheet）。

資料來源（已全數確認，無缺口）
- **每週逐週資料** = `WeeklyPreviewV2.weeks: [WeekPreview]`（`Havital/Features/TrainingPlanV2/Domain/Entities/WeeklyPreviewV2.swift`），每週含 `week`/`stageId`/**`targetKm`**(+Display/unit)/`isRecovery`/`milestoneRef`/`intensityRatio`/**`qualityOptions`**(key workouts)/**`longRun`**。取得：`getWeeklyPreview(overviewId:)`（TrainingPlanV2 repo，已有 local cache + TTL）。→ PhaseRoadmap 每週「計畫 km」= `WeekPreview.targetKm`；key workout = `qualityOptions`/`longRun`。
- **實際 km** = `viewModel.weeklySummaries`（已跑週的 actual）。
- **支援賽事 pin** = `targetViewModel.sortedSupportingTargets`（[Target]，`isMainRace==false`，來自 TargetManager）；總覽 sheet `PlanOverviewSheetV2.swift:235` 已用 `SupportingRacesCard` 呈現。→ 依各支援賽事日期映射到 roadmap 對應週次畫 pin。
- **L2 趨勢圖**：本次不做。`FitnessGapGauge`/「查看趨勢圖」入口先隱藏。

## Component Architecture

> 全部 Presentation 層；不碰 Domain/Data（沿用既有 ViewModel + repository）。無新 API、無 DB 變更。

### TrainingOverviewV2View（新，取代 TrainingPlanOverviewDetailView 的呈現）
- Layer：presentation
- 依賴：既有 `TrainingPlanV2ViewModel`（overview / weeklySummaries / weeklyPlan / 導航），不直接碰 repository impl。
- 責任：單頁滾動容器；組合 HeroHeader → StatsCard(race) → PhaseRoadmapView → MethodologyStrategyCard → MilestonesCard。
- 不做：趨勢圖 L2、訓練紀錄清單。

### OverviewHeroHeader（新）
- 漸層底（accent = 當前階段色 [race] / 品牌藍 [starter/maintain]）；標題（race name / targetName）+ 編輯入口；倒數天數[race]；「●階段·第N/M週」chip。
- 資料：`PlanOverviewV2` + 當前週。

### PhaseRoadmapView（新，核心；吸收 TrainingProgressView）
- 垂直 roadmap，一行一階段（`trainingStages`）；可展開當前階段 → 該階段所有週（`weekStart...weekEnd`），每週一列含：週次、計畫/實際 km、key workout、current 標記、**「課表」與「週回顧」入口 icon**。
- 賽事 pin：主賽事 finish line（race）；支援賽事 nested（若有來源）。
- 導航：「課表」→ 既有單週課表（`PlannedSessionDetail`/週課表入口）；「週回顧」→ 既有週回顧 sheet（`selectedWeekForSummary` → WeeklySummary）。
- 不做：自己抓資料（沿用 ViewModel）。

### MethodologyStrategyCard（新）
- `methodologyOverview`（名稱/風格/描述）+ `approachSummary`（策略段落），合併一卡。

### MilestonesCard（新）
- `milestones` 列表。

### 入口/導航遷移
- 首頁「⋯」選單「訓練總覽」→ 改開 `TrainingOverviewV2View`。
- 首頁原「訓練進度」卡片/入口（`TrainingPlanView` 內）→ 移除或改導向新總覽（待確認首頁是否保留進度卡片入口）。
- `TrainingProgressView` 刪除（或保留檔案但移除入口，過渡期）。

## 資料決策（已與用戶確認）

1. **每週 km**（用戶：「weekly_preview 有啊」）→ 計畫 km = `WeekPreview.targetKm`；已跑週疊 `weeklySummaries` 實際 km；key workout = `qualityOptions`/`longRun`。
2. **支援賽事 pin**（用戶：「要支援賽事啊，畫面不是有」）→ 用 `targetViewModel.sortedSupportingTargets`，依賽事日期映射到 roadmap 週次畫 pin。
3. **訓練進度檔案**（用戶：「直接刪除」）→ 刪 `TrainingProgressView.swift` + 所有入口引用。
4. **趨勢圖入口**：本次隱藏 `FitnessGapGauge`/「查看趨勢圖」。

## Cross-Repo Impact

| Repo | Impact | Sync? |
|------|--------|-------|
| iOS | 新增 TrainingOverviewV2View + 子元件；刪 TrainingProgressView；改總覽入口 | 本次 |
| Android | parity 待辦（Android 也有總覽/進度）；本次 iOS 先行，記錄差異供 Android 對齊 | 否（後續） |
| Backend | 無（沿用 plan_overview_v2 + weekly summaries；無新欄位） | 否 |

## DB Schema Changes
None.

## Task Breakdown（subagent-driven）

| # | Task | Role | Done Criteria |
|---|------|------|--------------|
| 1 | TrainingOverviewV2View 容器 + Hero + Stats(race) | iOS Dev | 單頁滾動；race/starter/maintain 三模式 hero 正確；build 過；模擬器截圖 |
| 2 | PhaseRoadmapView（階段列 + 展開週清單 + 課表/週回顧 入口）吸收 TrainingProgressView | iOS Dev | 當前階段展開顯示各週 + 可點進課表/週回顧；資料沿用 ViewModel；截圖 |
| 3 | MethodologyStrategyCard + MilestonesCard | iOS Dev | 方法論+策略合併卡、里程碑卡；截圖 |
| 4 | 入口遷移：總覽選單 → V2；移除訓練進度入口 + 刪 TrainingProgressView | iOS Dev | 舊入口改導向 V2；無殘留引用；build 過 |
| 5 | i18n + AppFont token + 模擬器三模式驗收 | iOS Dev/QA | 無寫死字串；字體走 token；三模式截圖逐項對照設計 |

## Risk Assessment

### Uncertain Technical Points
- 支援賽事日期 → roadmap 週次的映射：需用 raceDate 對 overview startDate/週區間換算（時區：raceDate 為 UTC timestamp，需走既有換算）。
- WeeklyPreview 可能尚未載入/過期（有 TTL）→ 需 fallback（先 trainingStages range，preview 到位後刷新）。

### Alternative Approaches and Selection Rationale
- (A) 原地改寫 TrainingPlanOverviewDetailView vs (B) 新建 TrainingOverviewV2View 並切換入口。選 (B)：可並存對照、降風險、易回退。

### Decisions Requiring User Confirmation
- 全部已確認：每週 km=WeekPreview.targetKm＋weeklySummaries 實際；支援賽事=sortedSupportingTargets pin；TrainingProgressView 直接刪除；L2 不做。

### Worst-Case Scenario and Correction Cost
- 最壞：PhaseRoadmap 週清單導航接錯既有課表/週回顧頁 → 中等修正成本（導航接點明確，單檔可改）。新建畫面不動資料層，回退＝切回舊總覽入口。
