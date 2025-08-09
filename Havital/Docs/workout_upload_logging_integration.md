# Workout 上傳失敗 Cloud Logging 整合

## 概述

已成功在 workout 上傳失敗時增加 Firebase Cloud Logging 紀錄，記錄 `user_id`、`workout_id` 和失敗原因，方便進行交叉比對和問題分析。

## 整合位置

### 1. WorkoutService.swift
**位置**: `postWorkoutDetails` 方法

**記錄的失敗情況**:
- **心率數據不足**: 當心率數據筆數少於1筆時
- **HTTP錯誤**: 當API返回非2xx狀態碼時
- **API錯誤**: 當上傳過程中發生其他錯誤時

**記錄的資訊**:
```json
{
  "workout_id": "workout_uuid",
  "user_id": "firebase_user_uid",
  "error_type": "錯誤類型",
  "error_message": "錯誤描述",
  "workout_type": "運動類型",
  "workout_start_date": "開始時間戳",
  "workout_end_date": "結束時間戳",
  "source": "數據來源",
  "device": "設備型號",
  "heart_rate_count": "心率數據筆數",
  "speed_count": "速度數據筆數",
  "http_status_code": "HTTP狀態碼（僅HTTP錯誤）"
}
```

### 2. WorkoutBackgroundUploader.swift
**位置**: `uploadPendingWorkouts` 方法

**記錄的失敗情況**:
- **上傳錯誤**: 在背景上傳過程中發生的任何錯誤

**記錄的資訊**:
```json
{
  "workout_id": "workout_uuid",
  "user_id": "firebase_user_uid",
  "error_type": "錯誤類型",
  "error_message": "錯誤描述",
  "workout_type": "運動類型",
  "workout_start_date": "開始時間戳",
  "workout_end_date": "結束時間戳",
  "is_force_upload": "是否強制上傳",
  "send_notifications": "是否發送通知",
  "bulk_sync": "是否批量同步"
}
```

### 3. WorkoutBackgroundManager.swift
**位置**: 
- `retryUploadingWithHeartRateData` 方法
- `uploadWorkouts` 方法

**記錄的失敗情況**:
- **重試上傳失敗**: 重新嘗試上傳心率數據時失敗
- **缺少心率數據**: 運動記錄缺少心率數據
- **一般上傳失敗**: 其他上傳錯誤

**記錄的資訊**:
```json
{
  "workout_id": "workout_uuid",
  "user_id": "firebase_user_uid",
  "error_type": "錯誤類型",
  "error_message": "錯誤描述",
  "workout_type": "運動類型",
  "workout_start_date": "開始時間戳",
  "workout_end_date": "結束時間戳",
  "retry_type": "重試類型（僅重試失敗）",
  "elapsed_since_end": "距離運動結束的時間（僅缺少心率數據）",
  "send_individual_notifications": "是否發送個別通知（僅一般上傳失敗）"
}
```

## 日誌等級

| 失敗類型 | 日誌等級 | 說明 |
|----------|----------|------|
| 心率數據不足 | `warning` | 非嚴重錯誤，可能是暫時性問題 |
| 缺少心率數據 | `warning` | 需要稍後重試的情況 |
| HTTP錯誤 | `error` | 服務器端錯誤 |
| API錯誤 | `error` | 網絡或API相關錯誤 |
| 重試失敗 | `error` | 重試後仍然失敗 |
| 一般上傳失敗 | `error` | 其他上傳相關錯誤 |

## 標籤系統

所有日誌都包含以下標籤用於分類和篩選：

- `module`: 模組名稱（WorkoutService、WorkoutBackgroundUploader、WorkoutBackgroundManager）
- `action`: 操作類型（upload、background_upload、retry_upload）
- `failure_reason`: 失敗原因（insufficient_heart_rate_data、http_error、api_error、upload_error、retry_upload_error、missing_heart_rate_data）

## 查詢範例

### 在 Firebase Console 中查詢特定用戶的失敗記錄

```javascript
// 查詢特定用戶的所有上傳失敗
db.collection('logs_prod')
  .where('userId', '==', 'user_uid')
  .where('labels.failure_reason', 'in', ['http_error', 'api_error', 'upload_error'])

// 查詢特定運動記錄的失敗
db.collection('logs_prod')
  .where('jsonPayload.workout_id', '==', 'workout_uuid')

// 查詢心率數據相關的失敗
db.collection('logs_prod')
  .where('labels.failure_reason', 'in', ['insufficient_heart_rate_data', 'missing_heart_rate_data'])

// 查詢特定時間範圍的失敗
db.collection('logs_prod')
  .where('timestamp', '>=', startDate)
  .where('timestamp', '<=', endDate)
  .where('level', '==', 'ERROR')
```

## 監控建議

### 1. 錯誤率監控
- 追蹤每日上傳失敗率
- 監控特定錯誤類型的發生頻率
- 設置錯誤率閾值警報

### 2. 用戶體驗監控
- 追蹤特定用戶的失敗模式
- 監控設備類型的失敗率差異
- 分析運動類型的失敗關聯性

### 3. 系統健康監控
- 監控HTTP錯誤狀態碼分布
- 追蹤API響應時間與失敗的關係
- 分析網絡條件對上傳成功的影響

## 故障排除

### 常見問題分析

1. **心率數據不足**
   - 檢查設備是否正確記錄心率
   - 分析運動類型與心率數據的關係
   - 考慮調整心率數據最小要求

2. **HTTP錯誤**
   - 檢查服務器狀態
   - 分析特定狀態碼的出現模式
   - 驗證API端點配置

3. **網絡錯誤**
   - 分析用戶網絡環境
   - 檢查上傳時間與網絡穩定性
   - 考慮實現重試機制

## 後續優化

1. **自動化分析**: 建立自動化腳本分析失敗模式
2. **預警系統**: 設置基於失敗率的自動預警
3. **用戶通知**: 在特定失敗情況下主動通知用戶
4. **性能優化**: 基於失敗分析優化上傳策略 