---
type: TD
id: TD-training-v2-edit-strength
status: Draft
ontology_entity: training-plan-v2-edit-experience
created: 2026-03-29
updated: 2026-03-29
---

# Technical Design: V2 課表編輯——力量訓練支援

## 對應 Spec

`Docs/specs/SPEC-training-v2-edit-schedule-screen.md`

---

## Bug 根因分析（R5 拖拉調換天次）

### 已修復的問題（commit 2b01a08 + 本次修復）

**問題一：SessionWrapperDTO 遺失 supplementary（數據層）**

Server 回傳嵌套格式 `session.{primary, supplementary}` 時，`SessionWrapperDTO` 只解析 `primary`，`supplementary` 靜默丟失。

```swift
// 修復前（TrainingSessionDTOs.swift）
struct SessionWrapperDTO: Codable {
    let primary: PrimaryActivityDTO?
    // 缺少 supplementary
}

// 修復後
struct SessionWrapperDTO: Codable {
    let primary: PrimaryActivityDTO?
    let supplementary: [SupplementaryActivityDTO]?
}
// DayDetailDTO.init 使用 flatSupplementary ?? sessionWrapper.supplementary
```

**問題二：SimplifiedDailyCardV2 未顯示 supplementary（UI 層）**

編輯卡片只顯示主訓練摘要，force swap 後用戶看不到力量補充訓練，誤以為資料消失。

```swift
// 修復後（EditScheduleViewV2.swift）
// 在 detailsView 中加入 supplementaryActivitiesSummary
// 顯示「➕ [type] · [duration]分鐘」
```

**問題三：buildDayDetailDTO 硬寫空 exercises（Commit 2b01a08）**

`MutableTrainingDay` 缺少 `strengthExercises`/`strengthType`/`supplementaryActivities` 欄位，`buildDayDetailDTO` 中 exercises 硬寫 `[]`、strengthType 硬寫 `"general"`、supplementary 硬寫 `nil`。

已在 commit 2b01a08 修復：`MutableTrainingDay.init(from: DayDetail)` 正確提取以上三個欄位。

### onMove 交換邏輯驗證

`EditScheduleViewV2` 的 `onMove` 處理器：
```swift
editingDays.move(fromOffsets: source, toOffset: destination)
for i in editingDays.indices {
    editingDays[i].dayIndex = "\(i + 1)"
}
```
交換整個 `MutableTrainingDay` value（含 `supplementaryActivities`），只重設 `dayIndex`，邏輯**正確**。唯一需注意的是 `MutableTrainingDay` 必須完整保留所有欄位，已由 Bug 三的修復確保。

---

## 現有實作狀況

### 已完成（本 session 修復）

| 需求 | 狀態 | 說明 |
|------|------|------|
| R5 拖拉調換完整保留資料 | ✅ 已修復 | SessionWrapperDTO + UI 顯示 + exercises 保留 |
| R1 力量日顯示正確編輯器 | ✅ 已修復 | StrengthEditorV2：type 選擇、duration Stepper |
| R1 儲存 strengthType/duration | ✅ 已修復 | TrainingDayEditState → toMutableTrainingDay |

### 待實作

| 需求 | 狀態 |
|------|------|
| R1 動作層級編輯（組數、次數、重量） | ❌ 待實作 |
| R2 任意天次新增力量訓練 | ❌ 待實作 |
| R3 任意天次刪除力量訓練 | ❌ 待實作 |
| R4 動作 CRUD | ❌ 待實作 |

---

## Component 架構

### R1 — 力量日動作層級編輯

擴充現有 `StrengthEditorV2`，將 exercises 從 read-only 改為可編輯：

```
TrainingEditSheetV2
  └── StrengthEditorV2（已存在）
        ├── strengthType Menu（已存在）
        ├── duration Stepper（已存在）
        └── ExerciseListEditor（新增）
              ├── ForEach exercises → ExerciseRowEditor
              └── 新增動作按鈕
```

**`ExerciseRowEditor`** — 每行動作：
- 名稱 TextField（必填）
- 組數 Stepper (1–10)
- 次數 TextField（支援 "8-12" 字串格式）
- 重量 TextField（kg，可選）
- 刪除按鈕

**狀態管理**：`TrainingDayEditState` 已有 `strengthExercises: [Exercise]?`，改為 `@Published var strengthExercises: [MutableExercise]`（新建可觀察的 mutable wrapper）。

**MutableExercise**（新增至 `MutableTrainingModels.swift`）：
```swift
struct MutableExercise: Identifiable {
    var id: String        // 保留原 exerciseId
    var name: String
    var sets: Int?
    var reps: String?     // 支援 "8-12" 格式
    var durationSeconds: Int?
    var weightKg: Double?
    var restSeconds: Int?
    var description: String?
}
```

### R2 — 任意天次新增力量訓練

**跑步日/交叉訓練日**：在 `StrengthEditorV2` 加入「+ 新增補充力量訓練」按鈕。
- 點擊後在 `TrainingDayEditState` 建立空白 `MutableExercise` 陣列，填入 `supplementaryStrengthExercises`
- 儲存時透過 `toMutableTrainingDay` 寫入 `supplementaryActivities`

**休息日**：`TrainingEditSheetV2` 中顯示「轉為力量訓練日」按鈕。
- 點擊後將 `trainingType` 改為 `strength`，`category` 改為 `strength`
- 進入力量訓練編輯器

### R3 — 任意天次刪除力量訓練

- **力量補充訓練日**（跑步+力量）：在 `StrengthEditorV2` 加入「移除力量訓練」按鈕，清空 `supplementaryStrengthExercises`
- **力量主訓練日**：在力量編輯器加入「改為休息日」按鈕，`trainingType = "rest"`

---

## DTO / API Payload

`buildDayDetailDTO` 需對應 R4 exercise 編輯：

```swift
// MutableExercise → ExerciseDTO（已存在 ExerciseDTO struct）
ExerciseDTO(
    exerciseId: exercise.id,
    name: exercise.name,
    sets: exercise.sets,
    reps: exercise.reps.flatMap { Int($0) },
    repsRange: Int(exercise.reps ?? "") == nil ? exercise.reps : nil,
    durationSeconds: exercise.durationSeconds,
    weightKg: exercise.weightKg,
    restSeconds: exercise.restSeconds,
    description: exercise.description
)
```

現有 `buildDayDetailDTO` 中力量訓練的 `exercises` 轉換邏輯已正確，只需確保 source 改用 `MutableExercise` 陣列。

---

## 任務拆分

### DEV-1：R1 + R4 動作層級編輯

**檔案**：`TrainingDetailEditor.swift`, `MutableTrainingModels.swift`

**Done Criteria**：
1. 新增 `MutableExercise` struct 至 `MutableTrainingModels.swift`
2. `TrainingDayEditState` 中 `strengthExercises` 改為 `[MutableExercise]`
3. 實作 `ExerciseListEditor` + `ExerciseRowEditor`（名稱必填、組數/次數/重量可選）
4. `StrengthEditorV2` 嵌入 `ExerciseListEditor`，支援新增/刪除動作
5. `toMutableTrainingDay` 正確將 `MutableExercise` 轉回 `Exercise` 型別
6. Clean build 通過

### DEV-2：R2 任意天次新增力量訓練

**檔案**：`TrainingDetailEditor.swift`, `EditScheduleViewV2.swift`

**Done Criteria**：
1. 非力量日（跑步/交叉/休息）的 `TrainingEditSheetV2` 出現「+ 新增力量訓練」按鈕
2. 跑步/交叉訓練日新增後，力量以 `supplementaryActivities` 保存
3. 休息日新增後，`trainingType` 切換為 `strength`，category 更新
4. 新增但未輸入任何動作時顯示 validation toast
5. Clean build 通過

### DEV-3：R3 任意天次刪除力量訓練

**檔案**：`TrainingDetailEditor.swift`

**Done Criteria**：
1. 力量主訓練日：編輯器顯示「改為休息日」按鈕，點擊後 trainingType = "rest"
2. 有力量補充訓練的跑步日：顯示「移除力量訓練」按鈕，點擊後清空 supplementary
3. 刪除後儲存，週課表該日不再顯示力量訓練
4. Clean build 通過

---

## Spec 介面合約

| Spec 需求 | 介面/行為 | Done Criteria 對應 |
|-----------|----------|-------------------|
| R1: strength_type 可編輯 | `StrengthEditorV2` Menu picker → `TrainingDayEditState.strengthType` → `buildDayDetailDTO.strengthType` | DEV-1 DC-5 |
| R1: exercises 可新增/刪除/編輯 | `ExerciseListEditor` → `MutableExercise[]` → `ExerciseDTO[]` | DEV-1 DC-3/4/5 |
| R2: 跑步日新增 supplementary | `supplementaryActivities: [.strength(...)]` in payload | DEV-2 DC-2 |
| R2: 休息日轉力量日 | category = "strength", primary = .strength(...) | DEV-2 DC-3 |
| R3: 刪除力量訓練 | supplementaryActivities 清空 或 trainingType = "rest" | DEV-3 DC-1/2 |
| R4: 動作組數/次數/重量 | ExerciseDTO.sets/reps/repsRange/weightKg | DEV-1 DC-5 |
| R5: 拖拉保留完整資料 | MutableTrainingDay 含 supplementaryActivities | ✅ 已修復 |

---

## 風險與不確定性

### 已解決
- SessionWrapperDTO 數據遺失：已修復
- 力量日顯示錯誤編輯器：已修復

### 待確認
- R4 Exercise `reps` 欄位為 `String?`（支援 "8-12" 格式），與 `ExerciseDTO.reps: Int?` + `repsRange: String?` 的轉換邏輯需細心測試
- Demo Mode 無力量訓練資料，QA 需用真實帳號或模擬資料驗證 R2/R3

### 不確定性
- R2/R3 的 UI 入口點（按鈕放哪）需 QA 視覺驗證後確認 UX 合理
