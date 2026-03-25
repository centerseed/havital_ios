# Plan Brief: fix-interval-edit-bugs

## Goal
修復間歇訓練編輯的兩個 bug：100m 間歇被預設值覆蓋、原地休息儲存後距離仍顯示。

## BDD Spec
→ Behavioral contract: `docs/bdd/fix-interval-edit-bugs.feature`
  Scenarios in scope: @ac1, @ac2

## Metadata
- affected: app
- db_migration: false
- deploy_required: false

## AC → Test Mapping
| AC Tag | Scenario Name | Test Type | Test File | Platform |
|--------|--------------|-----------|-----------|----------|
| @ac1 | 短距離間歇保持原始距離 | manual | N/A | app |
| @ac2 | 原地休息不顯示距離 | manual | N/A | app |

## Bug 1: 100m 間歇被覆蓋為 400m (@ac1)

### Root Cause
`TrainingDayEditState.init(from:)` 第 56 行：
```swift
self.workDistance = details?.work?.distanceKm ?? 0.4
```
後端對 100m 大步跑傳 `workDistanceM = 100`，`workDistanceKm = nil`。
`workDistance` 回落到預設值 `0.4`（400m），原始 100m 資料遺失。

### Fix
`TrainingDetailEditor.swift` 第 56 行，改為同時考慮 `distanceKm` 和 `distanceM`：
```swift
self.workDistance = details?.work?.distanceKm
    ?? details?.work?.distanceM.map { $0 / 1000.0 }
    ?? 0.4
```

---

## Bug 2: 原地休息儲存後主畫面仍顯示距離 (@ac2)

### Root Cause（兩個問題疊加）

**問題 A — IntervalBlockDTO 省略 nil 欄位**

`IntervalBlockDTO` 使用自動合成 Codable，nil 值直接從 JSON 省略（不送出），而非明確送 `null`。

資料流追蹤：
1. 使用者設定原地休息 → `recovery = MutableWorkoutSegment(distanceKm: nil, ...)`
2. `buildRunActivityDTO()` 建立 `IntervalBlockDTO(recoveryDistanceKm: nil, recoveryDistanceM: nil, ...)`
3. 自動 Codable 編碼時 nil 欄位被省略 → JSON 不包含 `recovery_distance_km`
4. 後端收到無 `recovery_distance_km` 的 JSON → 視為「不修改」→ 舊距離保留

**問題 B — recoveryDurationSeconds 寫死為 nil**

`EditScheduleV2ViewModel.swift` 第 264 行：
```swift
recoveryDurationSeconds: nil,  // ← 硬寫 nil，不用 recovery.timeSeconds
```
原地休息的秒數永遠不會送到後端。

### Fix

**Fix A — IntervalBlockDTO 加自定義 encoder（關鍵修復）**

在 `TrainingSessionDTOs.swift` 的 `IntervalBlockDTO` 加入 custom `encode(to:)`，
對所有 recovery 相關欄位使用 `encode`（非 `encodeIfPresent`），確保 nil 送出為 `null`：

```swift
func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(repeats, forKey: .repeats)
    try container.encodeIfPresent(workDistanceKm, forKey: .workDistanceKm)
    try container.encodeIfPresent(workDistanceM, forKey: .workDistanceM)
    try container.encodeIfPresent(workDistanceDisplay, forKey: .workDistanceDisplay)
    try container.encodeIfPresent(workDistanceUnit, forKey: .workDistanceUnit)
    try container.encodeIfPresent(workPaceUnit, forKey: .workPaceUnit)
    try container.encodeIfPresent(workDurationMinutes, forKey: .workDurationMinutes)
    try container.encodeIfPresent(workPace, forKey: .workPace)
    try container.encodeIfPresent(workDescription, forKey: .workDescription)
    // Recovery 欄位：明確編碼 nil 為 null，確保後端能清除舊值
    try container.encode(recoveryDistanceKm, forKey: .recoveryDistanceKm)
    try container.encode(recoveryDistanceM, forKey: .recoveryDistanceM)
    try container.encode(recoveryDurationMinutes, forKey: .recoveryDurationMinutes)
    try container.encode(recoveryPace, forKey: .recoveryPace)
    try container.encodeIfPresent(recoveryDescription, forKey: .recoveryDescription)
    try container.encode(recoveryDurationSeconds, forKey: .recoveryDurationSeconds)
    try container.encodeIfPresent(variant, forKey: .variant)
}
```

**Fix B — 傳送 recoveryDurationSeconds**

`EditScheduleV2ViewModel.swift` 第 264 行：
```swift
// Before:
recoveryDurationSeconds: nil,
// After:
recoveryDurationSeconds: recovery.timeSeconds,
```

---

## Implementation Notes
- Reference: `MutableWorkoutSegment.encode(to:)` 已有相同手法（明確編碼 nil 為 null）
- Bug 1 修復影響：`workDistance` 初始化邏輯，所有間歇類型（interval, strides, hillRepeats 等）
- Bug 2 修復影響：所有編輯後儲存間歇訓練的 API 請求

## Files to Change
| File | AC | Change |
|------|-----|--------|
| `Havital/Views/Training/EditSchedule/TrainingDetailEditor.swift:56` | @ac1 | `workDistance` 初始化考慮 `distanceM` |
| `Havital/Features/TrainingPlanV2/Data/DTOs/TrainingSessionDTOs.swift` | @ac2 | `IntervalBlockDTO` 加 custom encoder |
| `Havital/Features/TrainingPlanV2/Presentation/ViewModels/EditScheduleV2ViewModel.swift:264` | @ac2 | `recoveryDurationSeconds` 用 `recovery.timeSeconds` |

## Files That Must NOT Change
- `TrainingSessionModels.swift` — Domain Entity 不需要修改
- `MutableTrainingModels.swift` — Mutable 模型已正確處理

## Out of Scope
- 後端 API 行為修改（null vs missing field handling）
- V1 兼容層的 WeekTimelineView（只修 V2）
- 間歇模板預設值調整

## PAUSE Gates
- [ ] DB migration: no
- [ ] Test data deletion: no
- [ ] Deployment: no
