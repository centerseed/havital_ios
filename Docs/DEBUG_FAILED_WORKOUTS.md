# 調試失敗的運動記錄指南

## 📋 概述

本指南說明如何使用新增的調試功能來查詢和分析上傳失敗的運動記錄。

## 🔧 新增的調試功能

### 1. WorkoutUploadTracker 的調試方法

在 `Havital/Storage/WorkoutUploadTracker.swift` 中新增了兩個公開的調試方法：

#### `debugPrintAllFailedWorkouts()`
打印所有失敗的運動記錄，按失敗時間降序排列。

```swift
WorkoutUploadTracker.shared.debugPrintAllFailedWorkouts()
```

**輸出示例：**
```
📋 [DEBUG] 所有失敗的運動記錄 (3 個):
==================================================

📌 Workout ID: 1699564800_1699568400_1
   首次失敗: 2025-11-11 10:30:15
   最後失敗: 2025-11-11 14:22:45
   重試次數: 3/3
   失敗原因: 缺少必要數據: heart_rate

📌 Workout ID: 1699551600_1699555200_3
   首次失敗: 2025-11-10 18:15:30
   最後失敗: 2025-11-10 19:45:00
   重試次數: 2/3
   失敗原因: 缺少必要數據: speed_or_distance, cadence_or_laps

==================================================
```

#### `debugFindFailedWorkoutsOnDate(_ date: Date)`
搜尋特定日期的所有失敗運動記錄。

```swift
let date = Date()  // 或指定日期
WorkoutUploadTracker.shared.debugFindFailedWorkoutsOnDate(date)
```

**輸出示例：**
```
🔍 [DEBUG] 2025-11-05 失敗的運動記錄 (1 個):
==================================================

📌 Workout ID: 1730748600_1730752200_1
   失敗時間: 14:30:00
   重試次數: 1/3
   失敗原因: 缺少必要數據: speed_or_distance

==================================================
```

### 2. UI 調試界面

在 DEBUG 構建版本中，用戶資料頁面新增了調試選項：

**路徑：** 用戶資料頁面 → 🧪 開發者測試 → 調試 - 失敗運動記錄

**UI 功能：**
- 📊 顯示失敗統計（總失敗、永久失敗數量）
- 🔍 按日期搜尋失敗運動
- 📋 打印所有失敗記錄
- 🗑️ 清除所有失敗記錄

## 🔍 如何查找 11/5 的 ~5km 運動

### 步驟 1：使用 UI 調試界面

1. 打開應用並進入用戶資料頁面
2. 向下滾動至「🧪 開發者測試」部分
3. 點擊「調試 - 失敗運動記錄」
4. 選擇日期 `2025-11-05`
5. 點擊「搜尋此日期的失敗記錄」

記錄將打印到 Xcode Console（如果運行在模擬器或連接到 Xcode）。

### 步驟 2：使用代碼直接查詢

在 Xcode Console 中執行（需要 LLDB 支持）：

```swift
WorkoutUploadTracker.shared.debugFindFailedWorkoutsOnDate(Date(timeIntervalSince1970: 1730748600))
```

或使用 Swift Playgrounds：

```swift
import Foundation

let november5 = DateComponents(calendar: Calendar.current, year: 2025, month: 11, day: 5).date!
WorkoutUploadTracker.shared.debugFindFailedWorkoutsOnDate(november5)
```

## 📊 理解失敗原因

### 失敗原因代碼

| 失敗原因 | 說明 | 解決方案 |
|---------|------|--------|
| `heart_rate` | 心率數據不足 | 重新同步 Apple Health，確保穿戴設備有心率記錄 |
| `speed_or_distance` | 無 GPS 速度也無距離信息 | 對於室內運動正常，API 可推算速度；對於 GPS 運動需重新同步 |
| `cadence_or_laps` | 既無步頻也無分圈 | 重新同步分圈數據或步頻信息 |
| `API 上傳失敗: ...` | API 伺服器拒絕 | 檢查網絡連接和 API 狀態 |

### Workout ID 格式

```
startTimestamp_endTimestamp_activityType
```

**例子：** `1730748600_1730752200_1`
- 開始時間戳: `1730748600` (Nov 5, 2025, 14:30 UTC)
- 結束時間戳: `1730752200` (Nov 5, 2025, 15:30 UTC)
- 運動類型: `1` (HKWorkoutActivityType.running)

### 時間戳轉換

將時間戳轉換為日期：

```python
# Python
from datetime import datetime
timestamp = 1730748600
date = datetime.utcfromtimestamp(timestamp)
print(date)  # 2025-11-05 14:30:00
```

或在 Swift：

```swift
let timestamp = 1730748600
let date = Date(timeIntervalSince1970: Double(timestamp))
print(date)  // 2025-11-05 14:30:00 +0000
```

## 🔄 失敗記錄生命週期

### 記錄被創建
當運動驗證失敗時：
```
[Upload] 數據驗證失敗 - 運動ID: ...
❌ 第一層驗證失敗 - 心率數據不足
```

### 記錄被更新
每次重試失敗時重試計數遞增：
```
🚨 [WorkoutUploadTracker] 記錄上傳失敗: 1730748600_1730752200_1
   - 重試次數: 1/3
   - 失敗原因: 缺少必要數據: heart_rate
```

### 記錄被清除
上傳成功時：
```
✅ [WorkoutUploadTracker] 清除失敗記錄: 1730748600_1730752200_1
```

或達到最大重試次數後被跳過：
```
⚠️ [WorkoutUploadTracker] Workout ... 已達最大重試次數 (3/3)，跳過上傳
```

## 💡 常見問題排查

### Q: 為什麼 11/5 的運動沒有記錄？

**可能的原因：**
1. 運動從未嘗試上傳（未同步到應用）
2. 運動已上傳成功（記錄被清除）
3. 運動記錄已被清理（默認只保留最近 200 條）

**驗證步驟：**
1. 執行 `debugFindFailedWorkoutsOnDate()` 搜尋
2. 如果無結果，檢查上傳成功記錄：`WorkoutUploadTracker.shared.getUploadedWorkoutsCount()`
3. 檢查原始 HealthKit 數據是否存在

### Q: 為什麼說「3/3」但仍在嘗試上傳？

重試次數達到最大後，系統會在 30 分鐘冷卻期後檢查是否應重試。檢查冷卻期：

```swift
let stats = WorkoutUploadTracker.shared.getFailureStats()
print("總失敗: \(stats.totalFailed)")
print("永久失敗: \(stats.permanentlyFailed)")
```

### Q: 如何強制清除失敗記錄並重新上傳？

```swift
// 清除所有失敗記錄
WorkoutUploadTracker.shared.clearAllFailureRecords()

// 然後觸發重新同步
await AppStateManager.shared.initializeApp()
```

## 📝 新增的文件

| 文件 | 說明 |
|------|------|
| `Havital/Storage/WorkoutUploadTracker.swift` | 新增 `debugPrintAllFailedWorkouts()` 和 `debugFindFailedWorkoutsOnDate()` 方法 |
| `Havital/Views/Settings/DebugFailedWorkoutsView.swift` | 新建調試 UI 視圖 |
| `Havital/Views/UserProfileView.swift` | 新增開發者選項和調試按鈕 |

## 🚀 使用建議

1. **定期檢查：** 在開發過程中定期檢查失敗記錄，及時發現驗證邏輯問題
2. **保存日誌：** 複製 Console 輸出保存以便分析趨勢
3. **清理測試數據：** 完成調試後清除失敗記錄，避免干擾真實數據
4. **監控 Apple Health 同步：** 觀察特定運動的同步時機，調整重試策略

## 📚 相關文檔

- [SPEED_DATA_VALIDATION_ANALYSIS.md](SPEED_DATA_VALIDATION_ANALYSIS.md) - 速度數據驗證策略
- [AppleHealthWorkoutUploadService.swift](../Havital/Services/AppleHealthWorkoutUploadService.swift) - 上傳服務實現

---

**最後更新：** 2025-11-13
**調試版本：** 適用於 DEBUG 構建
