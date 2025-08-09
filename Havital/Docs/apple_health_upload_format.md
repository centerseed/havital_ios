# Apple Health 上傳資料格式規範

本文件詳細說明從 iOS App 上傳 Apple Health 運動數據到 `/v2/workouts` API 的資料格式。

## API 端點資訊

- **端點**: `POST /v2/workouts`
- **認證**: `Authorization: Bearer {firebase_token}`
- **Content-Type**: `application/json`

## 請求資料結構

### 完整 JSON 範例

```json
{
  "source_info": {
    "name": "apple_health",
    "import_method": "app_sdk"
  },
  "activity_profile": {
    "type": "running",
    "start_time_utc": "2024-12-25T10:30:00Z",
    "end_time_utc": "2024-12-25T11:15:00Z",
    "duration_total_seconds": 2700
  },
  "summary_metrics": {
    "distance_meters": 5000.0,
    "active_calories_kcal": 320.5,
    "avg_heart_rate_bpm": 145,
    "max_heart_rate_bpm": 168
  },
  "time_series_streams": {
    "timestamps_seconds_offset": [0, 10, 20, 30, 40, 50],
    "heart_rate_bpm": [120, 135, 145, 150, 155, 160]
  }
}
```

## 欄位詳細說明

### 1. source_info (必填)

標識資料來源和導入方法。

```json
{
  "name": "apple_health",           // 固定值：資料來源名稱
  "import_method": "app_sdk"        // 固定值：導入方法
}
```

### 2. activity_profile (必填)

運動活動的基本資訊。

```json
{
  "type": "running",                      // 運動類型，參見下方映射表
  "start_time_utc": "2024-12-25T10:30:00Z", // ISO8601 格式的開始時間
  "end_time_utc": "2024-12-25T11:15:00Z",   // ISO8601 格式的結束時間  
  "duration_total_seconds": 2700           // 總持續時間（秒）
}
```

**注意**: `start_time_utc` 可能為 null，但 `end_time_utc` 和 `duration_total_seconds` 必須存在。

### 3. summary_metrics (選填)

運動的摘要指標，所有欄位都是選填的。

```json
{
  "distance_meters": 5000.0,        // 總距離（公尺）
  "active_calories_kcal": 320.5,    // 消耗卡路里（千卡）
  "avg_heart_rate_bpm": 145,        // 平均心率（每分鐘次數）
  "max_heart_rate_bpm": 168         // 最大心率（每分鐘次數）
}
```

### 4. time_series_streams (選填)

時間序列數據，用於詳細的運動分析。

```json
{
  "timestamps_seconds_offset": [0, 10, 20, 30, 40, 50], // 相對於開始時間的偏移量（秒）
  "heart_rate_bpm": [120, 135, 145, 150, 155, 160]     // 對應時間點的心率數據
}
```

**數據特性**:
- `timestamps_seconds_offset`: 以運動開始時間為基準的相對時間偏移
- 兩個陣列長度必須相同
- 心率數據取整為整數

## 運動類型映射表

Apple Health 運動類型會映射為以下標準類型：

| Apple Health 類型 | API 類型 |
|------------------|----------|
| `running`, `trackAndField` | `running` |
| `walking` | `walking` |
| `cycling`, `handCycling` | `cycling` |
| `swimming`, `swimBikeRun` | `swimming` |
| `hiking` | `hiking` |
| `yoga`, `mindAndBody` | `yoga` |
| `traditionalStrengthTraining`, `functionalStrengthTraining` | `strength_training` |
| `highIntensityIntervalTraining` | `hiit` |
| `crossTraining` | `cross_training` |
| `mixedCardio` | `mixed_cardio` |
| `pilates` | `pilates` |
| 其他未列出類型 | `other` |

## 時間格式說明

- **時間格式**: ISO8601 UTC 格式 (`YYYY-MM-DDTHH:mm:ssZ`)
- **時區**: 所有時間都轉換為 UTC
- **精確度**: 秒級精確度

## 數據處理邏輯

### 心率數據處理
1. 從 HealthKit 獲取運動期間的心率數據
2. 計算平均心率和最大心率
3. 將心率數據轉換為相對時間偏移的時間序列
4. 所有心率值取整為整數

### 距離和卡路里
- 距離從 HealthKit 單位轉換為公尺
- 卡路里從 HealthKit 單位轉換為千卡

## API 回應格式

### 成功回應

```json
{
  "id": "running_1735120200_123",
  "schema_version": "2.0",
  "provider": "apple_health",
  "created_at": "2024-12-25T11:15:00Z",
  "basic_metrics": {
    "total_duration_s": 2700,
    "total_distance_m": 5000.0,
    "avg_heart_rate_bpm": 145
  },
  "advanced_metrics": {
    "dynamic_vdot": 42.5,
    "tss": 65.2
  },
  "message": "Workout uploaded successfully"
}
```

### 錯誤回應

```json
{
  "success": false,
  "error": {
    "code": "INVALID_DATA",
    "message": "Missing required field: activity_profile.end_time_utc"
  }
}
```

## 常見問題

### 1. 數據缺失處理
- 如果沒有心率數據，`summary_metrics` 中的心率欄位將為 null
- 如果沒有距離數據（如瑜伽），`distance_meters` 將為 null
- `time_series_streams` 完全選填，可以不包含

### 2. 大數據集處理
- 心率數據可能包含數千個數據點
- 系統會自動處理大型時間序列數據
- 建議每10秒一個數據點以平衡精確度和性能

### 3. 重複數據檢測
- 系統會根據開始時間、結束時間和運動類型檢測重複數據
- 重複的運動記錄會被自動忽略或更新

## 範例場景

### 場景 1: 完整的跑步記錄（包含心率）
```json
{
  "source_info": {
    "name": "apple_health",
    "import_method": "app_sdk"
  },
  "activity_profile": {
    "type": "running",
    "start_time_utc": "2024-12-25T06:00:00Z",
    "end_time_utc": "2024-12-25T07:00:00Z",
    "duration_total_seconds": 3600
  },
  "summary_metrics": {
    "distance_meters": 10000.0,
    "active_calories_kcal": 600.0,
    "avg_heart_rate_bpm": 150,
    "max_heart_rate_bpm": 175
  },
  "time_series_streams": {
    "timestamps_seconds_offset": [0, 60, 120, 180, 240, 300],
    "heart_rate_bpm": [130, 140, 150, 160, 165, 170]
  }
}
```

### 場景 2: 瑜伽課程（無距離和心率）
```json
{
  "source_info": {
    "name": "apple_health",
    "import_method": "app_sdk"
  },
  "activity_profile": {
    "type": "yoga",
    "start_time_utc": "2024-12-25T08:00:00Z",
    "end_time_utc": "2024-12-25T09:00:00Z",
    "duration_total_seconds": 3600
  },
  "summary_metrics": {
    "distance_meters": null,
    "active_calories_kcal": 200.0,
    "avg_heart_rate_bpm": null,
    "max_heart_rate_bpm": null
  }
}
```

### 場景 3: 力量訓練（僅基本指標）
```json
{
  "source_info": {
    "name": "apple_health",
    "import_method": "app_sdk"
  },
  "activity_profile": {
    "type": "strength_training",
    "start_time_utc": "2024-12-25T18:00:00Z",
    "end_time_utc": "2024-12-25T19:00:00Z",
    "duration_total_seconds": 3600
  },
  "summary_metrics": {
    "distance_meters": null,
    "active_calories_kcal": 300.0,
    "avg_heart_rate_bpm": 110,
    "max_heart_rate_bpm": 140
  }
}
```

## 建議的後端處理邏輯

1. **數據驗證**:
   - 驗證必填欄位存在
   - 檢查時間格式正確性
   - 確認時間序列數據陣列長度一致

2. **數據轉換**:
   - 將 UTC 時間轉換為適當的時區（如需要）
   - 正規化運動類型
   - 計算衍生指標（如平均配速）

3. **重複檢測**:
   - 基於開始時間、結束時間和運動類型建立唯一性檢查
   - 考慮時間容差（如 ±30 秒）

4. **錯誤處理**:
   - 提供清晰的錯誤訊息
   - 記錄詳細的錯誤日誌以便除錯

## 更新記錄

- **v1.0** (2024-12-25): 初始版本，定義基本資料格式
- **v1.1** (2024-12-25): 添加詳細範例和常見問題 