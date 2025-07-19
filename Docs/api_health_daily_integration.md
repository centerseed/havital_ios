# `/v2/workouts/health_daily` API 整合說明文件

## 概述
這個 API 用於取得用戶的每日健康數據，包括每日卡路里消耗、心率變異性（HRV）和靜息心率等重要健康指標。

## API 基本資訊

### 端點
```
GET /v2/workouts/health_daily
```

### 認證
- 需要 Firebase JWT Token
- 在 HTTP Header 中加入：`Authorization: Bearer {firebase_jwt_token}`

### 請求參數

| 參數名稱 | 類型 | 必填 | 預設值 | 最大值 | 說明 |
|---------|------|------|--------|--------|------|
| `limit` | integer | 否 | 7 | 30 | 要取得的天數，必須為正整數 |

### 請求範例

#### 基本請求（取得最近7天）
```http
GET /v2/workouts/health_daily
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### 指定天數（取得最近14天）
```http
GET /v2/workouts/health_daily?limit=14
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

## 回應格式

### 成功回應 (200)
```json
{
  "success": true,
  "data": {
    "health_data": [
      {
        "date": "2025-07-19",
        "daily_calories": 2100,
        "hrv_last_night_avg": 45.2,
        "resting_heart_rate": 62
      },
      {
        "date": "2025-07-18", 
        "daily_calories": 2050,
        "hrv_last_night_avg": 44.8,
        "resting_heart_rate": 61
      }
    ],
    "count": 2,
    "limit": 14
  }
}
```

### 健康數據欄位說明

| 欄位名稱 | 類型 | 說明 | 單位 |
|---------|------|------|------|
| `date` | string | 日期，格式：YYYY-MM-DD | - |
| `daily_calories` | integer/null | 每日卡路里消耗 | 卡路里 |
| `hrv_last_night_avg` | float/null | 昨夜平均心率變異性 | 毫秒 |
| `resting_heart_rate` | integer/null | 靜息心率 | BPM |

**注意**: 所有健康指標欄位都可能為 `null`，代表該日期沒有相關數據。

### 錯誤回應

#### 參數錯誤 (400)
```json
{
  "success": false,
  "error": "Limit must be a positive integer"
}
```

```json
{
  "success": false,
  "error": "Limit cannot exceed 30 days"
}
```

#### 認證錯誤 (401)
```json
{
  "success": false,
  "error": "Unauthorized"
}
```

## 資料特性

### 排序
- 數據按日期降序排列（最新的日期在前）
- 即使查詢 7 天，實際返回的記錄可能少於 7 筆（取決於用戶實際有數據的天數）

### 時區處理
- API 會自動使用用戶設定的時區進行日期計算
- 預設時區為 `Asia/Taipei`
- 日期以用戶當地時區為準

### 性能優化
- 實作記憶體快取機制，提升查詢效率
- 使用 Firestore batch 操作減少網路延遲

## App 端整合建議

### 1. 錯誤處理
```swift
// Swift 範例
func fetchHealthDaily(limit: Int = 7) async throws -> HealthDailyResponse {
    guard limit > 0 && limit <= 30 else {
        throw APIError.invalidParameter("Limit must be between 1 and 30")
    }
    
    let url = "\(baseURL)/v2/workouts/health_daily?limit=\(limit)"
    let request = createAuthenticatedRequest(url: url)
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200:
                return try JSONDecoder().decode(HealthDailyResponse.self, from: data)
            case 400:
                throw APIError.badRequest("Invalid parameters")
            case 401:
                throw APIError.unauthorized("Authentication failed")
            default:
                throw APIError.serverError("Server error")
            }
        }
    } catch {
        throw APIError.networkError(error.localizedDescription)
    }
}
```

### 2. 資料模型定義
```swift
// Swift 資料模型
struct HealthDailyResponse: Codable {
    let success: Bool
    let data: HealthDailyData
}

struct HealthDailyData: Codable {
    let healthData: [HealthRecord]
    let count: Int
    let limit: Int
    
    enum CodingKeys: String, CodingKey {
        case healthData = "health_data"
        case count, limit
    }
}

struct HealthRecord: Codable {
    let date: String
    let dailyCalories: Int?
    let hrvLastNightAvg: Double?
    let restingHeartRate: Int?
    
    enum CodingKeys: String, CodingKey {
        case date
        case dailyCalories = "daily_calories"
        case hrvLastNightAvg = "hrv_last_night_avg"
        case restingHeartRate = "resting_heart_rate"
    }
}
```

### 3. UI 顯示建議
- 對於 `null` 值，建議顯示為 "無數據" 或使用預設圖示
- 可以根據數據完整性顯示不同的 UI 狀態
- 建議實作下拉更新功能
- 可以快取數據以提升用戶體驗

### 4. 分頁策略
- 由於最大限制為 30 天，如需更多歷史數據，建議：
  - 實作日期範圍查詢（如果後續 API 支援）
  - 或分批請求不同時間段的數據

## 常見問題

### Q: 為什麼有些健康指標顯示為 null？
A: 這表示用戶在該日期沒有相關的健康數據記錄，可能是設備未佩戴或數據同步問題。

### Q: 數據更新頻率如何？
A: 健康數據通常每日更新一次，具體取決於用戶的設備同步頻率。

### Q: 可以查詢特定日期的數據嗎？
A: 目前 API 只支援查詢最近 N 天的數據，如需特定日期查詢功能，請聯繫後端團隊。

### Q: HRV 數值的正常範圍是什麼？
A: HRV 因人而異，一般成年人的 HRV 範圍在 20-60ms 之間，但建議關注個人趨勢變化而非絕對數值。

## 測試建議

1. **邊界值測試**：測試 limit=1, limit=30, limit=0, limit=31
2. **空數據測試**：測試新用戶或沒有健康數據的情況
3. **網路異常測試**：測試網路中斷、超時等情況
4. **認證測試**：測試無效或過期的 JWT token

## 更新記錄

- **2025-07-19**: 初版文件發布
- 包含完整的 API 規格說明和整合建議