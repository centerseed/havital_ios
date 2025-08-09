# Workout 上傳架構重構說明

## 🎯 **重構目標**

解決原本多個地方重複實現workout上傳邏輯的問題，統一使用一個核心上傳方法。

## 🏗️ **重構前 vs 重構後**

### 重構前（問題）
```
❌ 多個重複的上傳實現：
├── WorkoutService.postWorkoutDetails() - 核心API調用
├── WorkoutBackgroundUploader.uploadPendingWorkouts() - 重複邏輯
├── WorkoutBackgroundManager.uploadWorkouts() - 重複邏輯  
└── WorkoutBackgroundManager.retryUploadingWithHeartRateData() - 重複邏輯
```

### 重構後（解決方案）
```
✅ 統一的架構：
WorkoutService.uploadWorkout() ← 唯一的核心上傳方法
    ↓
其他所有地方都調用這個方法
```

## 📁 **文件變更**

### 1. WorkoutService.swift - 核心服務
**新增方法：**
- `uploadWorkout(_:force:retryHeartRate:source:device:)` - 統一的單個workout上傳
- `uploadWorkouts(_:force:retryHeartRate:)` - 統一的批量workout上傳

**新增類型：**
- `UploadResult` - 單個上傳結果
- `UploadBatchResult` - 批量上傳結果
- `FailedWorkout` - 失敗的workout資訊

### 2. WorkoutBackgroundUploader.swift - 簡化
**變更：**
- 移除重複的數據獲取和上傳邏輯
- 使用 `WorkoutService.uploadWorkouts()` 進行批量上傳
- 保留通知管理和設備資訊獲取功能

### 3. WorkoutBackgroundManager.swift - 簡化
**變更：**
- 移除重複的數據獲取和上傳邏輯
- 使用 `WorkoutService.uploadWorkouts()` 進行上傳
- 保留背景任務管理和調度功能

### 4. WorkoutDetailView.swift - 更新
**變更：**
- 手動上傳按鈕使用 `WorkoutService.uploadWorkout()` 方法

## 🔄 **使用方式**

### 單個 Workout 上傳
```swift
// 基本上傳
let result = try await WorkoutService.shared.uploadWorkout(workout)

// 強制上傳（跳過心率檢查）
let result = try await WorkoutService.shared.uploadWorkout(workout, force: true)

// 重試心率數據
let result = try await WorkoutService.shared.uploadWorkout(workout, retryHeartRate: true)
```

### 批量 Workout 上傳
```swift
// 批量上傳
let result = await WorkoutService.shared.uploadWorkouts(workouts)

// 強制批量上傳
let result = await WorkoutService.shared.uploadWorkouts(workouts, force: true)

// 重試心率數據的批量上傳
let result = await WorkoutService.shared.uploadWorkouts(workouts, retryHeartRate: true)
```

## 📊 **結果處理**

### UploadResult 枚舉
```swift
enum UploadResult {
    case success(hasHeartRate: Bool)
    case failure(error: Error)
}
```

### UploadBatchResult 結構
```swift
struct UploadBatchResult {
    let total: Int           // 總數
    let success: Int         // 成功數
    let failed: Int          // 失敗數
    let failedWorkouts: [FailedWorkout]  // 失敗詳情
}
```

## 🎯 **重構優勢**

### 1. **代碼重用**
- 消除重複邏輯，減少代碼量
- 統一的錯誤處理和日誌記錄

### 2. **維護性**
- 修改上傳邏輯只需要改一個地方
- 更容易測試和除錯

### 3. **一致性**
- 所有上傳都使用相同的邏輯
- 統一的參數和返回值

### 4. **可擴展性**
- 新增功能只需要修改核心方法
- 更容易添加新的上傳選項

## 🔧 **Firebase Logging 整合**

重構後，所有上傳失敗都會統一記錄到 Firebase Cloud Logging：

- **模組標籤**: `WorkoutService`
- **動作標籤**: `upload`, `batch_upload`
- **失敗原因**: `insufficient_heart_rate_data`, `http_error`, `api_error`, `upload_error`

## 📝 **遷移指南**

### 對於現有代碼
1. **直接調用**: 使用 `WorkoutService.uploadWorkout()` 或 `uploadWorkouts()`
2. **錯誤處理**: 使用新的 `UploadResult` 和 `UploadBatchResult` 類型
3. **參數調整**: 根據需要設置 `force` 和 `retryHeartRate` 參數

### 對於新功能
- 直接使用 `WorkoutService` 的統一方法
- 不需要實現自己的上傳邏輯

## 🚀 **未來改進**

1. **重試機制**: 可以在 `WorkoutService` 中添加自動重試邏輯
2. **進度回調**: 可以添加上傳進度的回調函數
3. **並發控制**: 可以添加並發上傳的限制
4. **緩存機制**: 可以添加上傳結果的緩存

## ✅ **測試建議**

1. **單個上傳測試**: 測試各種參數組合
2. **批量上傳測試**: 測試大量workout的上傳
3. **錯誤處理測試**: 測試網絡錯誤、數據錯誤等情況
4. **Firebase Logging測試**: 確認日誌記錄正確 