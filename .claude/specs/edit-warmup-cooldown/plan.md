# Plan Brief: edit-warmup-cooldown

## Goal
讓 V2 訓練課表中的暖跑（warmup）和緩和跑（cooldown）在編輯流程中可被保留、顯示、編輯，並在調整日期順序時不遺失。

## BDD Spec
→ Behavioral contract: `docs/bdd/edit-warmup-cooldown.feature`
  Scenarios in scope: @ac1, @ac2, @ac3, @ac4, @ac5, @ac6, @ac7, @ac8

## Metadata
- affected: app
- db_migration: false
- deploy_required: false

## AC → Test Mapping
| AC Tag | Scenario Name | Test Type | Test File | Platform |
|--------|--------------|-----------|-----------|----------|
| @ac1 | Warmup/cooldown preserved in edit mode | manual | — | app |
| @ac2 | Warmup/cooldown preserved after save | manual | — | app |
| @ac3 | Warmup/cooldown preserved on reorder | manual | — | app |
| @ac4 | Edit warmup distance | manual | — | app |
| @ac5 | Edit cooldown distance | manual | — | app |
| @ac6 | Default warmup/cooldown for new intensity | manual | — | app |
| @ac7 | No warmup/cooldown for easy runs | manual | — | app |
| @ac8 | Warmup/cooldown in daily card summary | manual | — | app |

## Implementation Notes

### 問題根因
資料流有 3 個斷點導致 warmup/cooldown 遺失：
1. `MutableTrainingDay` 無 warmup/cooldown 欄位
2. `TrainingDayEditState` 無 warmup/cooldown 編輯欄位
3. `buildDayDetailDTO` 硬編碼 `warmup: nil, cooldown: nil`

### 參考實作
- 間歇訓練 work/recovery 編輯模式：`TrainingDetailEditor.swift` IntervalEditorV2
- WarmupCooldownView 顯示組件：已存在，可復用

### 需要新增的類型判斷
不需要暖跑/緩和跑的類型（排除名單）：
- `easyRun`, `easy`, `recovery_run`, `lsd`, `rest`
- `strength`, `crossTraining`, `yoga`, `hiking`, `cycling`
- `swimming`, `elliptical`, `rowing`

需要暖跑/緩和跑的類型（包含名單）：
- `tempo`, `threshold`, `interval`, `longRun`, `racePace`
- `strides`, `hillRepeats`, `cruiseIntervals`, `shortInterval`, `longInterval`
- `norwegian4x4`, `yasso800`, `fartlek`, `fastFinish`
- `combination`, `progression`, `race`

### 預設值計算
- Warmup: 2.0 km，配速 = `PaceCalculator.getSuggestedPace(for: "recovery", vdot:)` 或 fallback "6:30"
- Cooldown: 1.0 km，配速 = 同 warmup 配速
- 時間估算：`distanceKm / paceInKmPerMin`（從 pace 字串解析）

## Files to Change

### Step 1: Data Layer — 保留 warmup/cooldown (@ac1, @ac2, @ac3)

**`Havital/Models/MutableTrainingModels.swift`**
- `MutableTrainingDay` 新增 `warmup: RunSegment?` 和 `cooldown: RunSegment?` 欄位
- `init(from day: DayDetail)` 從 `day.session?.warmup` 和 `day.session?.cooldown` 讀取
- `init(from day: TrainingDay)` 從 `day.trainingDetails?.warmup` 和 `day.trainingDetails?.cooldown` 讀取（RunSegmentV2 = RunSegment）
- `Equatable` 也要比較 warmup/cooldown
- `createEmpty` 和自定義 init 加上 warmup/cooldown 參數（預設 nil）

**`Havital/Features/TrainingPlanV2/Presentation/ViewModels/EditScheduleV2ViewModel.swift`**
- `buildDayDetailDTO` 把 `day.warmup`/`day.cooldown` 轉為 `RunSegmentDTO` 傳給 API
- 只對跑步類型傳送 warmup/cooldown，非跑步類型傳 nil

### Step 2: Edit State — 暖跑/緩和跑編輯欄位 (@ac4, @ac5)

**`Havital/Views/Training/EditSchedule/TrainingDetailEditor.swift`**
- `TrainingDayEditState` 新增欄位：
  - `@Published var warmupDistance: Double` (預設 2.0)
  - `@Published var warmupPace: String` (自動從 VDOT 計算)
  - `@Published var cooldownDistance: Double` (預設 1.0)
  - `@Published var cooldownPace: String` (自動從 VDOT 計算)
  - `@Published var hasWarmup: Bool` (是否有暖跑)
  - `@Published var hasCooldown: Bool` (是否有緩和跑)
- `init(from day: MutableTrainingDay)` 讀取 `day.warmup`/`day.cooldown`
- `toMutableTrainingDay()` 把暖跑/緩和跑寫回 `MutableTrainingDay.warmup`/`.cooldown`
- 新增 computed property `needsWarmupCooldown: Bool` 判斷當前類型是否需要

### Step 3: Editor UI — 暖跑/緩和跑編輯區塊 (@ac4, @ac5, @ac7)

**`Havital/Views/Training/EditSchedule/TrainingDetailEditor.swift`**
- 新增 `WarmupCooldownEditorV2` View：
  - 暖跑開關 + 距離 picker
  - 緩和跑開關 + 距離 picker
  - 顯示自動計算的配速和預估時間
  - 視覺風格與 WarmupCooldownView 一致（🔥/❄️ 圖標、orange/blue 配色）
- 在 `TrainingEditSheetV2.editorSection` 中，對需要 warmup/cooldown 的類型，在主編輯器後方追加 `WarmupCooldownEditorV2`

### Step 4: Daily Card — 顯示暖跑/緩和跑摘要 (@ac8)

**`Havital/Features/TrainingPlanV2/Presentation/Views/EditScheduleViewV2.swift`**
- `SimplifiedDailyCardV2` 的 `detailsView` 在 complexTrainingSummary 下方，顯示暖跑/緩和跑摘要
- 使用小字 caption 格式：`🔥 暖跑 2km · ❄️ 緩和 1km`

### Step 5: 新建類型時自動加入預設暖跑/緩和跑 (@ac6)

**`Havital/Features/TrainingPlanV2/Presentation/Views/EditScheduleViewV2.swift`**
- `updateTrainingType()` 中，對需要暖跑/緩和跑的訓練類型，設定 `day.warmup` 和 `day.cooldown` 為預設 RunSegment
- 使用 `PaceCalculator.getSuggestedPace(for: "recovery", vdot:)` 計算配速

## Files That Must NOT Change
- `Havital/Features/TrainingPlanV2/Domain/Entities/TrainingSessionModels.swift` — Domain 層 RunSegment 已正確定義
- `Havital/Features/TrainingPlanV2/Data/DTOs/TrainingSessionDTOs.swift` — RunSegmentDTO 和 DayDetailDTO 已正確支援
- `Havital/Features/TrainingPlanV2/Data/Mappers/TrainingSessionMapper.swift` — Mapper 不需修改
- `Havital/Features/TrainingPlanV2/Presentation/Views/Components/WarmupCooldownView.swift` — 顯示組件不需修改

## Out of Scope
- 暖跑/緩和跑的心率區間編輯（由 VDOT 自動推算即可）
- 暖跑/緩和跑的 intensity 欄位編輯
- supplementary exercises 的編輯
- V1 TrainingPlanViewModel 的修改（V1 已棄用）

## Build Sequence
1. Step 1 先做 — 確保資料不遺失（即使不能編輯）
2. Step 2+3 一起做 — 編輯狀態和 UI
3. Step 4+5 最後做 — 顯示和預設值

## PAUSE Gates
- [ ] DB migration: no
- [ ] Test data deletion: no
- [ ] Deployment: no
