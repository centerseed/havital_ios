---
type: TD
id: TD-weekly-adjustment-selection
status: Draft
spec: SPEC-weekly-adjustment-selection.md
created: 2026-04-18
updated: 2026-04-18
---

# 技術設計：週回顧調整建議接受／拒絕

## 調查報告

### 已讀文件（附具體發現）

- `Docs/specs/SPEC-weekly-adjustment-selection.md` — 10 條 AC（P0×7, P1×2, P2×1）；技術約束指出 `onGenerateNextWeek` 需擴充
- `Docs/specs/SPEC-training-hub-and-weekly-plan-lifecycle.md` — AC-TRAIN-HUB-06 僅管「何時顯示按鈕」，與本 spec 不衝突
- `Havital/Features/TrainingPlanV2/Domain/Entities/WeeklySummaryV2.swift` — `AdjustmentItemV2` 已有 `apply: Bool`、`impact: String`；Domain 層無需修改
- `Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift:729-818` — `AdjustmentsSectionV2` 無 toggle；`AdjustmentItemCardV2` 顯示 content/reason，**未顯示 impact**；`onGenerateNextWeek: (() -> Void)?` 無參數
- `Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift:123-138` — 按鈕文字目前是靜態的 localizedString，非動態
- `Havital/Features/TrainingPlanV2/Presentation/Views/TrainingPlanV2View.swift:336-345` — 唯一觸發下週課表生成的 callsite；呼叫 `viewModel.generator.generateWeeklyPlanDirectly(weekNumber:)`
- `Havital/Features/TrainingPlanV2/Presentation/ViewModels/WeeklyPlanGenerator.swift:118-146` — `generateWeeklyPlanDirectly` 呼叫 `repository.generateWeeklyPlan(...)`，**無 adjustments 參數**（後端合約確認不需要）
- `Havital/Features/TrainingPlanV2/Presentation/ViewModels/WeeklySummaryCoordinator.swift` — 已存在 245 行；持有 `weeklySummary`；無 toggle state；**需擴充**
- `Havital/Features/TrainingPlanV2/Data/DTOs/TrainingPlanV2RequestDTOs.swift:61-73` — `GenerateWeeklyPlanRequest` 只有 4 欄位，**不需修改**（後端合約確認 apply-items 是獨立 endpoint）
- `Havital/Features/TrainingPlanV2/Data/DataSources/TrainingPlanV2RemoteDataSource.swift` — pattern 為 `apiHelper.post(DTO.self, path:, body:)`；需新增 apply-items method
- `Havital/Services/Core/APICallHelper.swift` — `post<T, B>` 用 `ResponseProcessor.extractData` 三步驟嘗試解析（UnifiedAPIResponse → APIResponse → 直接解析）

### 後端 API 合約（已確認）

**POST /v2/summary/weekly/apply-items**

Request:
```json
{
  "week_of_plan": 8,
  "applied_indices": [0, 2]
}
```

Response 200（`data` 欄位）:
```json
{
  "applies_to_week": 9,
  "applied_items": [{"index": 0, "type": "...", "content": "...", "applied": true}],
  "skipped_items": []
}
```

**關鍵業務邏輯（App 層級）：**
1. POST apply-items（帶選中 index）
2. POST /v2/plan/weekly（**不需傳 adjustments**，後端自動消費）

`GenerateWeeklyPlanRequest` 不需修改。

---

## AC Compliance Matrix

| AC ID | AC 描述 | 實作位置 | Test Function | 狀態 |
|-------|--------|---------|---------------|------|
| AC-WKADJ-01 | Toggle 預設從後端 apply 初始化 | `WeeklySummaryCoordinator.initializeSelections(from:)` | `test_ac_wkadj_01_toggle_default_from_backend_apply` | STUB |
| AC-WKADJ-02 | Toggle off 視覺弱化 | `AdjustmentItemCardV2` opacity + grayscale | `test_ac_wkadj_02_toggle_off_visual_dimming` | STUB |
| AC-WKADJ-03 | 只送已選 indices 到後端 | `WeeklySummaryCoordinator.applySelectedAdjustments(weekOfPlan:)` | `test_ac_wkadj_03_only_selected_indices_sent` | STUB |
| AC-WKADJ-04 | 全關閉送 `applied_indices: []` | `WeeklySummaryCoordinator.applySelectedAdjustments` empty path | `test_ac_wkadj_04_all_off_sends_empty_array` | STUB |
| AC-WKADJ-05 | 空清單不顯示 toggle | `AdjustmentsSectionV2` guard `!adjustments.items.isEmpty` | `test_ac_wkadj_05_empty_items_no_toggle` | STUB |
| AC-WKADJ-06 | 按鈕文字（N ≥ 1） | `WeeklySummaryV2View.actionButtonsView` | `test_ac_wkadj_06_button_text_with_selections` | STUB |
| AC-WKADJ-07 | 按鈕文字（0 條） | `WeeklySummaryV2View.actionButtonsView` | `test_ac_wkadj_07_button_text_no_selections` | STUB |
| AC-WKADJ-08 | Header 計數即時更新 | `WeeklySummaryCoordinator.selectedCount` + `CollapsibleSectionV2` subtitle | `test_ac_wkadj_08_header_count_updates` | STUB |
| AC-WKADJ-09 | `impact` 欄位顯示 | `AdjustmentItemCardV2` impact text | `test_ac_wkadj_09_impact_field_displayed` | STUB |
| AC-WKADJ-10 | 還原後端預設值 | `WeeklySummaryCoordinator.resetSelectionsToDefaults()` | `test_ac_wkadj_10_reset_to_defaults` | STUB |

---

## Component 架構

```
TrainingPlanV2View
  └── WeeklySummaryV2View
        ├── AdjustmentsSectionV2 (讀 coordinator.adjustmentSelections)
        │     └── AdjustmentItemCardV2 (toggle binding + impact 顯示)
        └── actionButtonsView (動態按鈕文字，讀 coordinator.selectedCount)

WeeklySummaryCoordinator (@Observable)
  ├── [NEW] adjustmentSelections: [Int: Bool]
  ├── [NEW] selectedCount: Int (computed)
  ├── [NEW] selectedIndices: [Int] (computed, sorted)
  ├── [NEW] initializeSelections(from: [AdjustmentItemV2])
  ├── [NEW] toggleAdjustment(at: Int)
  ├── [NEW] applySelectedAdjustments(weekOfPlan: Int) async -> Bool
  └── [NEW] resetSelectionsToDefaults()

TrainingPlanV2Repository (Domain Protocol)
  └── [NEW] func applyAdjustmentItems(weekOfPlan: Int, appliedIndices: [Int]) async throws

TrainingPlanV2RemoteDataSource (Protocol + Impl)
  └── [NEW] func applyAdjustmentItems(weekOfPlan: Int, appliedIndices: [Int]) async throws -> ApplyAdjustmentItemsResponseDTO

新 DTO:
  - ApplyAdjustmentItemsRequest (Request DTO)
  - ApplyAdjustmentItemsResponseDTO (Response DTO，data 欄位內容)
```

---

## 介面合約清單

### ApplyAdjustmentItemsRequest

| 欄位 | 型別 | 必填 | JSON key | 說明 |
|------|------|------|----------|------|
| weekOfPlan | Int | ✅ | week_of_plan | 週回顧的週次 |
| appliedIndices | [Int] | ✅ | applied_indices | 勾選的 item index（0-based）；`[]` = 全不套用 |

`use_coordinator` 固定不送（預設 false），MVP 不需要 LLM 衝突解析。

### ApplyAdjustmentItemsResponseDTO

| 欄位 | 型別 | JSON key | 說明 |
|------|------|----------|------|
| appliesToWeek | Int | applies_to_week | 本次調整套用到的週次 |
| skippedItems | [SkippedItemDTO] | skipped_items | mapper 轉換失敗的 item（不阻塞整批） |

`applied_items` 和 `coordinator_decision` 在 MVP 中不需解析，可略去或設為 optional。

### TrainingPlanV2Repository Protocol 新增方法

```swift
func applyAdjustmentItems(weekOfPlan: Int, appliedIndices: [Int]) async throws
```

（回傳 Void，iOS 只需知道成功 / 失敗，data 欄位不用於 UI 呈現）

### WeeklySummaryCoordinator 新增 API

```swift
var adjustmentSelections: [Int: Bool]          // observable
var selectedCount: Int                          // computed
var selectedIndices: [Int]                      // computed, sorted

func initializeSelections(from items: [AdjustmentItemV2])
func toggleAdjustment(at index: Int)
func applySelectedAdjustments(weekOfPlan: Int) async -> Bool
func resetSelectionsToDefaults()
```

---

## 關鍵設計決策

### 決策 1：apply-items 失敗時中止課表生成

AC-WKADJ-03 要求「只有開啟的建議被送往後端套用」。若 apply-items API 失敗，繼續生成課表會產生不含用戶選擇的課表，違反 AC-WKADJ-03 的語意。

**選擇：** apply-items 失敗 → `onNetworkError` toast + 回傳 `false` → `TrainingPlanV2View` guard `false` → 不呼叫 `generateWeeklyPlanDirectly`

### 決策 2：Toggle 狀態由 WeeklySummaryCoordinator 持有

SPEC 明確指出 "session-only，建議由 WeeklySummaryCoordinator 持有"。且 coordinator 是 `@Observable`，任何讀取 `adjustmentSelections` 的 View 都自動 re-render。

**不選用 @State in View：** view 是 private struct，需要同時在 `AdjustmentItemCardV2` 和 `actionButtonsView` 讀取選擇狀態，傳 binding 層數多且繁瑣。

### 決策 3：selections 在 summary 載入成功後立即初始化

`initializeSelections(from:)` 在所有 `weeklySummary = .loaded(summary)` 的路徑後呼叫（loadWeeklySummary / generateWeeklySummary / createWeeklySummaryAndShow）。歷史週回顧（`viewHistoricalSummary`）也初始化，但 toggle UI 不顯示（由 `onGenerateNextWeek == nil` 控制）。

### 決策 4：AdjustmentItemCardV2 接收 Binding<Bool>

`AdjustmentItemCardV2` 改為接收 `@Binding var isSelected: Bool` 而非 `let item`。Card 內部 Toggle 直接綁定。`AdjustmentsSectionV2` 則持有 `coordinator` 引用，生成每個 item 的 binding：`Binding(get: { coordinator.adjustmentSelections[index] ?? true }, set: { coordinator.adjustmentSelections[index] = $0 })`

---

## TrainingPlanV2View 修改重點

`onGenerateNextWeek` closure 原本：
```swift
{
    viewModel.summary.showWeeklySummary = false
    Task {
        try? await Task.sleep(nanoseconds: 600_000_000)
        let weekToGenerate = await viewModel.generator.resolveWeekToGenerateAfterSummary(summaryWeek: weekToShow)
        await viewModel.generator.generateWeeklyPlanDirectly(weekNumber: weekToGenerate)
    }
}
```

修改後：
```swift
{
    viewModel.summary.showWeeklySummary = false
    Task {
        try? await Task.sleep(nanoseconds: 600_000_000)
        let success = await viewModel.summary.applySelectedAdjustments(weekOfPlan: weekToShow)
        guard success else { return }
        let weekToGenerate = await viewModel.generator.resolveWeekToGenerateAfterSummary(summaryWeek: weekToShow)
        await viewModel.generator.generateWeeklyPlanDirectly(weekNumber: weekToGenerate)
    }
}
```

---

## DB Schema 變更

無。本功能不持久化 toggle 狀態。

---

## 任務拆分

| # | 任務 | 角色 | Done Criteria |
|---|------|------|--------------|
| S01 | 新增 ApplyAdjustmentItems DTO + DataSource + Repository | Developer | `ApplyAdjustmentItemsRequest` 可 encode 為正確 JSON；Protocol 通過 MockTrainingPlanV2Repository 新增 stub；clean build pass |
| S02 | WeeklySummaryCoordinator 新增 toggle state + applySelectedAdjustments | Developer | `initializeSelections` 從 apply 初始化；`applySelectedAdjustments` 呼叫 repository 並傳正確 indices；全關時傳 `[]`；失敗回傳 false；clean build pass |
| S03 | WeeklySummaryV2View UI：toggle + 按鈕文字 + impact + header 計數 | Developer | `AdjustmentItemCardV2` 有 toggle + opacity dimming + impact 文字；`actionButtonsView` 按鈕文字動態；section header 有「已選 N/M 條」；clean build pass |
| S04 | TrainingPlanV2View wiring：applySelectedAdjustments before generateWeeklyPlan | Developer | `onGenerateNextWeek` closure 先 await applySelectedAdjustments，成功才繼續；guard false 中止；clean build pass |
| QA | 驗收所有 10 條 AC | QA | AC-WKADJ-01 ~ 10 全部 PASS（含 simulator 操作截圖） |

---

## Risk Assessment

### 1. 不確定的技術點

- `ResponseProcessor.extractData` 對 apply-items response 的解析路徑（`UnifiedAPIResponse<T>` vs 直接解析），需 Developer 在 S01 整合後驗證回傳的 DTO 解析正確

### 2. 替代方案與選擇理由

| 替代方案 | 為什麼不選 |
|---------|-----------|
| Toggle 狀態放在 @State in WeeklySummaryV2View | 需要跨多個 private struct 傳 binding，且 coordinator 已是 @Observable，加欄位代價極低 |
| apply-items 失敗時靜默繼續生成課表 | 違反 AC-WKADJ-03 語意，用戶選擇的建議未被套用但課表仍生成，造成信任問題 |
| 在 generateWeeklyPlan request body 加 adjustments | 後端合約明確：generate endpoint 不接受此參數，apply-items 是獨立 endpoint |

### 3. 需要用戶確認的決策

- P2（AC-WKADJ-10，還原預設）是否包含在本次 Developer dispatch，或下次迭代？
  → 建議先做 S01-S04，P2 獨立一個 task（因為不影響 P0/P1 交付）

### 4. 最壞情況與修正成本

- apply-items endpoint 回傳格式與預期 DTO 不符 → `ResponseProcessor` fallback 到直接解析 / 報錯 → 修改 DTO 定義（低成本）
- `use_coordinator: false` 的 deterministic mapper 失敗（skipped_items 非空）→ 課表生成時自動忽略，無需 iOS 額外處理 → 成本為零

---

## Spec Compliance Matrix 對應 Test File

`HavitalTests/TrainingPlan/Spec/WeeklyAdjustmentSelectionACTests.swift`

---

## Done Criteria

Developer 交付前必須全部通過：

- [ ] `ApplyAdjustmentItemsRequest` encode 為 `{"week_of_plan": N, "applied_indices": [...]}`，欄位名稱符合後端合約
- [ ] `TrainingPlanV2Repository` protocol 有 `applyAdjustmentItems(weekOfPlan:appliedIndices:)` 方法
- [ ] `MockTrainingPlanV2Repository` 有對應 stub（`applyAdjustmentItemsCallCount`、`lastAppliedIndices`）
- [ ] `WeeklySummaryCoordinator.initializeSelections(from:)` 從 `item.apply` 初始化每個 index
- [ ] `WeeklySummaryCoordinator.applySelectedAdjustments(weekOfPlan:)` 傳入 `selectedIndices`（已排序），全關時傳 `[]`
- [ ] `WeeklySummaryCoordinator.applySelectedAdjustments(weekOfPlan:)` 失敗時呼叫 `onNetworkError` 並回傳 `false`
- [ ] `AdjustmentItemCardV2` 顯示 toggle，toggle off 時 `opacity(0.4)` + grayscale
- [ ] `AdjustmentItemCardV2` 顯示 `impact` 文字（`reason` 下方，顏色有所區隔）
- [ ] 按鈕文字：N ≥ 1 時「套用 N 條建議並產生下週課表」；0 條時「不套用調整，直接產生課表」
- [ ] Section header 展開後顯示「已選 N / M 條」
- [ ] `items.isEmpty` 時 `AdjustmentsSectionV2` 不渲染 toggle
- [ ] `TrainingPlanV2View.onGenerateNextWeek` closure：先 await applySelectedAdjustments，`guard success else { return }`
- [ ] `AC test stubs（AC-WKADJ-01 ~ 10）`從 FAIL 變 PASS
- [ ] `clean build pass`（`xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`）
