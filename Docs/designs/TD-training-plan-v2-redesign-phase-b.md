---
type: TD
id: TD-training-plan-v2-redesign-phase-b
status: Draft
l2_entity: training-plan-v2
created: 2026-05-18
updated: 2026-05-18
depends_on: TD-training-plan-v2-redesign-phase-a
---

# 技術設計：TrainingPlanV2 視覺重構 — Phase B

## 0. Context

Phase A (TD-training-plan-v2-redesign-phase-a) 已交付 commit `a73ddfe`：3 張主要 card 的視覺重構 + design token + 教練 segment 渲染。**Badge 用 placeholder、Race header / Starter-Maintain header 完全沒做、DayCard tap 還是 toggle expand 不是 push**。

本 TD 範圍：**主頁剩下未做的 5 件事**，全部已有資料來源（per Explore Survey 2026-05-18），不需要新 backend endpoint。

設計來源：`/tmp/paceriz-design/paceriz-app/project/training-plan.jsx`（同 Phase A）。

---

## 1. Investigation Report（Explore Survey 摘要）

| 元件 | 既有資料 | 新需求 |
|---|---|---|
| **Race info** | `PlanOverviewV2.raceDateValue: Date?` / `raceDate: Int?`、`TargetRepository.getMainTarget()`、`RaceEvent.daysUntilEvent` | 無新資料，只需聚合 |
| **Readiness** | `TrainingReadinessViewModel.overallScore`、`raceFitnessMetric.estimatedRaceTime`、`metrics.*.trendData` | **週 delta 要新算**（trendData 有但沒 weekly delta aggregator）|
| **Badge** | `AchievementRepository.getDisplayBadge()`、`fetchSummary().storySummary.recentUnlock` + `nextBadge` | **無新 repo**，wire 既有資料即可 |
| **Streak (連續訓練)** | `MonthlyStatsRepository.getMonthlyStats()` 給 `DailyStat.totalDistanceKm` | **streak 要 client-side compute**（沒 pre-computed 欄位）|
| **月里程** | 同上 — `DailyStat.totalDistanceKm` 自加總 | client-side sum |
| **DayCard 互動** | 目前 `.sheet(item:)` modal | **改 `.navigationDestination(item:)` push** |
| **Today CTA「開始今日訓練」** | iOS V2 沒有 start-workout 流程 | **fallback push `WorkoutDetailViewV2`** |

### 1.1 [unconfirmed]

- **TrainingPlanV2View 是否在 NavigationStack 容器內**（B4 需要）— Phase A 程式碼確認在 `NavigationStack { ZStack { ScrollView ... } }`，✓ 已驗證
- **AchievementRepository 是否在 DependencyContainer 已註冊**（B1 需要 inject 進 TrainingPlanV2ViewModel）— 待驗證

---

## 2. AC Compliance Matrix

| AC ID | AC | Implementation | Verification |
|---|---|---|---|
| AC-TPV2-B-01 | Race mode 顯示壓縮 race header（倒數 + 賽名 + 預估 vs 目標 + 適能 + 週 delta），單行/雙行 | `RaceHeaderViewV2.swift`（新）+ `RaceHeaderViewModelV2.swift`（新）| 模擬器截圖 race mode 用戶 |
| AC-TPV2-B-02 | Beginner / Maintenance mode 顯示 mode header（chip + 鼓勵訊息 + 連續/月里程/就緒）| `TrainingModeHeaderV2.swift`（新）+ `TrainingModeHeaderViewModelV2.swift`（新）| 模擬器截圖 beginner / maintenance 用戶 |
| AC-TPV2-B-03 | Volume card 徽章 hero 用真實 badge 資料（recentUnlock 優先、否則 nextBadge）| `WeekOverviewCardV2.swift` 改用 `BadgeRepository` 注入 | 截圖比對：用戶有 unlock 看到真徽章、沒 unlock 看到 nextBadge（灰階 + locked）|
| AC-TPV2-B-04 | DayCard tap：今日 inline expand 維持、其他日 tap → push `WorkoutDetailViewV2` | `WeekTimelineViewV2.swift` `.sheet` → `.navigationDestination` | 模擬器 tap 過去日 / 未來日，畫面 push 進詳情 |
| AC-TPV2-B-05 | 今日 card 底部「開始今日訓練」CTA button（藍色漸層 + Play icon），tap → push `WorkoutDetailViewV2(workout: 今日 first workout)` | `WeekTimelineViewV2.swift` TimelineItemViewV2 加 CTA | 模擬器今日 card 底部 button 可見可點 |
| AC-TPV2-B-06 | i18n 新增 key（race header / mode header / CTA button 等） | 3 個 `.lproj/Localizable.strings` | grep 新 keys 存在 |
| AC-TPV2-B-07 | Build PASS、原 Maestro flow 不破 | `xcodebuild clean build` + maestro plan flow | CI verification |
| AC-TPV2-B-08 | Design parity — race header / mode header / 徽章 hero 對齊 design jsx | side-by-side screenshot | QA 比對 |

---

## 3. Task Breakdown — 拆 5 個 sub-task（建議施作順序）

### Task B1 — Badge data wiring（最小，先做為基礎）

**改檔**：
- `WeekOverviewCardV2.swift`：接收 `badge: AchievementBadgeSnapshot?` 或 view model 暴露的 badge state
- `TrainingPlanV2ViewModel.swift` 或新 wrapper：注入 `AchievementRepository`，暴露 `currentBadge: AchievementBadgeSnapshot?`
- 既有 `PRPlaceholderBadge` 保留為 fallback（沒徽章資料 / 沒解鎖時用 SF Symbol）
- 新 view：`AchievementBadgeView`（顯示真實 badge image，從 asset 或 URL）

**Done Criteria**：
- [ ] AchievementRepository 注入 ViewModel
- [ ] `recentUnlock` 存在 → 顯示真實 badge image + NEW capsule
- [ ] `recentUnlock == nil` → 顯示 nextBadge 灰階 + 鎖頭 overlay
- [ ] 真實 badge 名取代 placeholder i18n key
- [ ] 移除 `PHASE_B_BADGE` 註解標記（資料層已接）

### Task B2 — Race header（新 view + 新 composite VM）

**新檔**：
- `Havital/Features/TrainingPlanV2/Presentation/Views/Components/RaceHeaderViewV2.swift`
- `Havital/Features/TrainingPlanV2/Presentation/ViewModels/RaceHeaderViewModelV2.swift`

**設計參考**（jsx L935-1010 `RaceHeader`）：
- Dark gradient bg (`linear-gradient(135deg, #1A1F2C 0%, #2A3550 100%)`)
- Single row layout：左「倒數 42 天」+ 中「賽名 / 差 X:XX / estimated → target」+ 右「適能 58 ↗+2」+ chevron
- Tap → push 表現數據頁（或 TBD）

**ViewModel 職責**：
- inject `TrainingPlanV2ViewModel`（或 PlanOverviewV2 + RaceRepository）+ `TrainingReadinessViewModel`
- 暴露：
  - `daysLeft: Int?`
  - `raceTitle: String?`
  - `estimatedFinish: String?` (from `raceFitnessMetric.estimatedRaceTime`)
  - `targetFinish: String?` (from PlanOverview or Target — 待 Explore Round 2)
  - `readinessScore: Int?`
  - `weekDelta: Int?`（**新算邏輯**：從 `readinessData.metrics.<key>.trendData.values` 取 today vs -7 days，相減）

**顯示條件**：`viewModel.loader.planOverview?.isRaceMode == true`

**Done Criteria**：
- [ ] Race mode 用戶看到 race header
- [ ] 非 race mode 用戶看不到（hidden）
- [ ] 顯示倒數天數正確
- [ ] 預估 → 目標時間 + gap 算法對
- [ ] Readiness + week delta 數字對

### Task B3 — Starter / Maintenance mode header

**新檔**：
- `Havital/Features/TrainingPlanV2/Presentation/Views/Components/TrainingModeHeaderV2.swift`
- `Havital/Features/TrainingPlanV2/Presentation/ViewModels/TrainingModeHeaderViewModelV2.swift`

**設計參考**（jsx L1017-1101 `TrainingModeHeader`）：
- Dark gradient bg（同 race header）
- mode chip (starter green 🌱 / maintain blue 🔄) + week 標示
- 鼓勵訊息（mode-specific tagline 或 backend message）
- 3-stat row：連續訓練 + 本月里程 + 就緒指數
- 就緒指數進度 bar

**ViewModel 職責**：
- inject `MonthlyStatsRepository` + `TrainingReadinessViewModel`
- **streak 算法**：從今天往回找連續 `DailyStat.hasWorkout == true` 天數
- **月里程**：當月 `DailyStat.totalDistanceKm` 加總
- **就緒指數**：reuse readiness `overallScore`

**顯示條件**：`isBeginnerTarget == true || isMaintenanceTarget == true`

**Done Criteria**：
- [ ] Beginner 用戶看到 green-themed mode header
- [ ] Maintenance 用戶看到 blue-themed mode header
- [ ] Race 用戶看不到此 header（race header 顯示）
- [ ] 3 個 stat 數字正確（streak / 月里程 / readiness）

### Task B4 — DayCard tap → push WorkoutDetail（互動模型變更）

**改檔**：
- `WeekTimelineViewV2.swift`：把 `.sheet(item: $selectedWorkout)` 改 `.navigationDestination(item: $selectedWorkout)`
- `TimelineItemViewV2`：今日仍 inline expand 不動；非今日的 `Button { isExpanded.toggle() }` 改成 `Button { onWorkoutSelect(workoutForThisDay) }` 或直接 wrap NavigationLink
- 「workoutForThisDay」是 `day.session` 對應的 WorkoutV2 entity（**待 Explore Round 2** — 如何從 DayDetail 取得 WorkoutV2，或需要新 mapper）

**保留行為**：
- 今日仍 inline expand（per Phase A 慣例 + 用戶 sign-off）
- 訓練類型 chip 仍 tap → TrainingTypeInfo sheet（不變）
- 休息日 chevron-right 但 tap 無反應（per F6.c 設計細節）

**Done Criteria**：
- [ ] Tap 過去日 / 未來日 → push WorkoutDetailViewV2 全螢幕
- [ ] 今日不 navigate，仍 inline expand
- [ ] 休息日 tap 無反應 OR 顯示 toast「休息日無詳情」
- [ ] Back button 回到 TrainingPlanV2View 不破狀態

### Task B5 — Today CTA「開始今日訓練」button

**改檔**：
- `WeekTimelineViewV2.swift` TimelineItemViewV2 今日 expanded 區塊底部加大 CTA

**設計參考**（jsx L885-896 today 按鈕）：
- 全寬、高 44pt
- `LinearGradient(.blue → .blueDeep)`
- Play icon + 「開始今日訓練」
- corner radius 12pt
- shadow `accent.opacity(0.55) radius 16 y 6`

**Action**：
- 最低門檻：push `WorkoutDetailViewV2(workout: 今日的 workout)`
- 用 NavigationLink 或 selectedWorkout binding

**Done Criteria**：
- [ ] 今日 card 底部可見 CTA button
- [ ] Tap → push 今日 workout detail
- [ ] 漸層 / 陰影 / 字級對齊設計
- [ ] i18n 新 key `training_plan.start_today_workout`（zh-Hant 「開始今日訓練」/ en 「Start today's workout」/ ja 「今日のトレーニング開始」）
- [ ] 休息日今日不顯示此 button

---

## 4. Cross-Repo Impact

| Repo | Impact |
|---|---|
| iOS | 3 改動檔 + 4 新增檔 + 3 .strings 新 keys |
| Android | 無 |
| Backend | 無 — 全部用既有 repo / endpoint |

---

## 5. Risk Assessment

### 5.1 不確定技術點

- **Week delta 算法**：trendData 結構是 `{values: [Double], dates: [Date]}`。取「today vs 7 天前」需準確 date 對應，可能要 fuzzy match（最接近 7 天前的有效 data point）。
- **Streak 邊界 case**：今天還沒訓練 vs 今天還沒過 → streak 算到昨天 vs 算到今天？要對齊 UX 預期
- **PlanOverview 中沒「target_finish_time」直接欄位**（待驗證）— 可能要從 `Target` entity 或別處取
- **DayDetail → WorkoutV2 mapping**：未來日沒對應 workout（還沒做），點開 detail 看什麼？空畫面？或從 plan day 構造一個 "preview workout"？

### 5.2 替代方案

- **B2/B3 共用基底 view**：兩個 header 視覺結構接近（dark gradient + mode chip + stats），可抽 `TrainingHeaderShellView` 共用。但 race vs starter/maintain 內容差異大，獨立 view 也合理。**選獨立**（簡單，未來變化容易）
- **B1 沒 badge asset 時**：iOS bundle 沒 badge PNG（per Phase A grep）→ B1 要先 copy `/tmp/paceriz-design/paceriz-app/assets/badges/*.png` 到 `Havital/Assets.xcassets/Badges.xcassets`，並加 Xcode target membership

### 5.3 需用戶確認

- **B4 休息日 tap 行為**：完全不可 tap、顯示 toast、或 push 「主動恢復日說明」頁？
- **B5 CTA tap 是否 record 「開始訓練」事件 to analytics**？
- **B2 race header tap 進「表現數據頁」是否要 Phase B 也做**，還是延後？

### 5.4 最壞情況

- B2 / B3 composite VM 設計失誤 → rollback 容易（純 view + VM 增量）
- B4 navigation 重構打破既有 sheet 流程 → backup test 跑 maestro plan flow

---

## 6. Dispatch Plan

TPM 將以本 TD dispatch 5 個 sub-task：

**建議順序**：
1. **B1（最小、基礎）** — 真實 badge wire，~3-5 小時
2. **B4 + B5（一輪 — 都動 WeekTimelineViewV2）** — push 互動 + 今日 CTA，~4-6 小時
3. **B2（race header） + B3（mode header）— 可並行（不同檔）** — ~6-8 小時 each

每個 sub-task 完成後跑 build + 模擬器自驗 + 截圖。全 5 個 done 後 QA Round 跑 design parity 比對。

**Architect 不可擴大 scope**：
- 不動 ViewModel 流程（除新增 inject）
- 不重寫 Domain Entity
- 不動 V1
- 不順手清 dead code
- 不 commit（等用戶授權）

---

## 7. 後續（Phase C 候選）

- 真實 start workout 流程（與 HealthKit / Activity 整合）
- WorkoutDetail 5 variants 重新設計（04a-e）— 設計稿已有
- TrainingLog / Performance / Achievements 三個 tab 重新設計
- DayCard 視覺 polish（type accent 顏色更細緻、進度視覺化）
