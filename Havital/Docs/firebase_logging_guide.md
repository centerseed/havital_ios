# Firebase Cloud Logging 使用指南

## 概述

這個 Firebase Logging 系統提供了一個簡單且強大的方式來將應用程式中的特定事件日誌上傳到 Firebase Firestore 和 Analytics，方便進行交叉比對和分析。

## 主要功能

- ✅ **雙重記錄**: 同時記錄到本地和 Firebase
- ✅ **結構化資料**: 支援 JSON 格式的結構化資料
- ✅ **標籤系統**: 可添加自定義標籤進行分類
- ✅ **事件追蹤**: 整合 Firebase Analytics 進行用戶行為分析
- ✅ **環境分離**: 開發和生產環境使用不同的集合
- ✅ **用戶關聯**: 自動關聯到當前登入用戶
- ✅ **設備資訊**: 自動記錄設備和應用程式版本資訊

## 快速開始

### 1. 基本日誌記錄

```swift
// 記錄一般資訊
Logger.firebase("用戶已成功登入", level: .info)

// 記錄警告
Logger.firebase("網路連線不穩定", level: .warn)

// 記錄錯誤
Logger.firebase("API 請求失敗", level: .error)
```

### 2. 帶標籤的日誌記錄

```swift
Logger.firebase(
    "訓練計劃同步完成",
    level: .info,
    labels: [
        "module": "TrainingPlan",
        "action": "sync",
        "status": "success"
    ]
)
```

### 3. 帶結構化資料的日誌記錄

```swift
let workoutData: [String: Any] = [
    "workoutId": "12345",
    "duration": 3600,
    "distance": 10.5,
    "calories": 750,
    "heartRate": [
        "average": 145,
        "max": 175
    ]
]

Logger.firebase(
    "運動記錄已上傳",
    level: .info,
    jsonPayload: workoutData
)
```

### 4. 事件記錄

```swift
// 記錄用戶行為事件
Logger.firebaseEvent(
    "user_completed_workout",
    parameters: [
        "workout_type": "running",
        "duration_minutes": 45,
        "distance_km": 5.2
    ]
)
```

## 在現有服務中的整合範例

### AuthenticationService

```swift
// 在 signInWithGoogle() 方法中
func signInWithGoogle() async {
    do {
        // ... 現有登入邏輯 ...
        
        // 記錄登入成功
        Logger.firebaseEvent("user_login_success", parameters: [
            "login_method": "google",
            "user_id": authResult.user.uid
        ])
        
    } catch {
        // 記錄登入失敗
        Logger.firebase("Google 登入失敗: \(error.localizedDescription)", level: .error)
    }
}
```

### WorkoutService

```swift
// 在同步運動數據時
func syncWorkouts() async {
    do {
        // ... 現有同步邏輯 ...
        
        Logger.firebase(
            "運動數據同步完成",
            level: .info,
            jsonPayload: [
                "sync_duration": duration,
                "workout_count": workouts.count,
                "upload_source": "healthkit"
            ]
        )
        
    } catch {
        Logger.firebase(
            "運動數據同步失敗",
            level: .error,
            jsonPayload: [
                "error_message": error.localizedDescription,
                "retry_count": retryCount
            ]
        )
    }
}
```

### GarminManager

```swift
// 在連接 Garmin 設備時
func connectGarmin() async {
    do {
        // ... 現有連接邏輯 ...
        
        Logger.firebaseEvent("garmin_connected", parameters: [
            "device_model": deviceModel,
            "connection_method": "oauth"
        ])
        
    } catch {
        Logger.firebase("Garmin 連接失敗: \(error.localizedDescription)", level: .error)
    }
}
```

## 日誌等級

| 等級 | 用途 | 範例 |
|------|------|------|
| `debug` | 調試資訊 | 函數進入/退出、變數值 |
| `info` | 一般資訊 | 用戶操作、業務流程 |
| `warning` | 警告 | 網路延遲、非關鍵錯誤 |
| `error` | 錯誤 | API 失敗、數據損壞 |
| `critical` | 嚴重錯誤 | 應用程式崩潰、安全問題 |

## 資料結構

每個日誌條目包含以下資訊：

```json
{
  "id": "UUID",
  "timestamp": "2024-01-01T12:00:00Z",
  "level": "INFO",
  "message": "用戶已成功登入",
  "sourceLocation": {
    "file": "AuthenticationService.swift",
    "line": 123,
    "function": "signInWithGoogle()"
  },
  "labels": {
    "module": "Authentication",
    "method": "google"
  },
  "jsonPayload": {
    "user_id": "abc123",
    "login_method": "google"
  },
  "userId": "user_uid",
  "deviceInfo": {
    "deviceModel": "iPhone 15 Pro",
    "osVersion": "iOS 17.2",
    "appVersion": "1.0.0",
    "buildNumber": "1",
    "bundleId": "com.havital.Havital"
  }
}
```

## Firebase 集合結構

- **開發環境**: `logs_dev`
- **生產環境**: `logs_prod`

每個文檔的 ID 是唯一的 UUID，方便查詢和追蹤。

## 查詢和分析

### 在 Firebase Console 中查詢

1. 打開 Firebase Console
2. 進入 Firestore Database
3. 選擇對應環境的集合 (`logs_dev` 或 `logs_prod`)
4. 使用查詢功能進行篩選

### 常用查詢範例

```javascript
// 查詢特定用戶的錯誤
db.collection('logs_prod')
  .where('userId', '==', 'user_uid')
  .where('level', '==', 'ERROR')

// 查詢特定模組的日誌
db.collection('logs_prod')
  .where('labels.module', '==', 'TrainingPlan')

// 查詢特定時間範圍的日誌
db.collection('logs_prod')
  .where('timestamp', '>=', startDate)
  .where('timestamp', '<=', endDate)
```

## 最佳實踐

### 1. 日誌內容

- **訊息要具體**: 避免模糊的描述
- **包含上下文**: 提供足夠的資訊來理解問題
- **使用結構化資料**: 對於複雜資訊使用 `jsonPayload`

### 2. 日誌等級

- **debug**: 僅在開發時使用
- **info**: 正常的業務流程
- **warning**: 可能影響用戶體驗的問題
- **error**: 需要關注的錯誤
- **critical**: 需要立即處理的嚴重問題

### 3. 標籤使用

- 使用一致的標籤命名
- 避免過多的標籤
- 使用標籤來分類和篩選

### 4. 性能考慮

- 日誌記錄是異步的，不會阻塞主線程
- 避免在循環中記錄大量日誌
- 對於高頻事件，考慮批量記錄

## 故障排除

### 常見問題

1. **日誌沒有上傳**
   - 檢查網路連線
   - 確認 Firebase 配置正確
   - 檢查 Firestore 權限設定

2. **日誌格式錯誤**
   - 確保 `jsonPayload` 中的資料是可序列化的
   - 避免循環引用

3. **查詢效能問題**
   - 為常用查詢建立索引
   - 使用適當的查詢條件

## 安全考慮

- 日誌中不要包含敏感資訊（密碼、token 等）
- 使用適當的 Firestore 安全規則
- 定期清理舊的日誌資料

## 監控和警報

建議設置以下監控：

1. **錯誤率監控**: 追蹤 ERROR 和 CRITICAL 等級的日誌數量
2. **性能監控**: 追蹤操作耗時
3. **用戶行為分析**: 追蹤功能使用情況
4. **異常檢測**: 檢測異常的日誌模式 