# 📱 App Workout 整合指南

本指南專為 App 開發團隊設計，說明如何整合 Paceriz 運動數據功能。

## 🏗️ 整體架構

### 資料流程
```
App ←→ API Service ←→ UnifiedWorkoutAdapter ←→ 多平台數據源
     ↓                    ↓                      ↓
  用戶界面        統一數據模型              Garmin/Apple Health
```

### 核心組件
- **API Service**: 提供統一的 REST API
- **UnifiedWorkoutAdapter**: 將不同平台數據轉換為統一格式
- **Workout V2 API**: 最新的運動數據 API，支援分頁和進階查詢
- **多平台支援**: Garmin (OAuth) + Apple Health (直接上傳)

## 🔄 資料來源切換

### 1. Garmin 資料來源
- **連接方式**: OAuth 授權
- **同步方式**: 後台自動同步
- **資料更新**: Webhook 即時推送 + 定期拉取

### 2. Apple Health 資料來源  
- **連接方式**: 直接上傳
- **同步方式**: App 主動上傳
- **資料更新**: 運動完成後立即上傳

### 3. 資料來源管理
```typescript
// 檢查用戶連接狀態
const getConnectionStatus = async () => {
  const response = await fetch('/api/v1/connect/status', {
    headers: { 'Authorization': `Bearer ${accessToken}` }
  });
  
  const data = await response.json();
  return data.data.connections; // [{ platform: 'garmin', status: 'connected' }, ...]
};

// 切換資料來源
const switchDataSource = (platform: 'garmin' | 'apple_health') => {
  if (platform === 'garmin') {
    // 啟動 Garmin OAuth 流程
    initiateGarminAuth();
  } else {
    // 啟動 Apple Health 上傳流程
    requestAppleHealthPermission();
  }
};
```

## 📱 Apple Health 資料上傳

### 1. iOS HealthKit 整合
```swift
import HealthKit

class HealthKitManager {
    private let healthStore = HKHealthStore()
    
    func requestAuthorization() async throws {
        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        try await healthStore.requestAuthorization(toShare: nil, read: readTypes)
    }
    
    func fetchWorkouts(from startDate: Date) async throws -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKWorkout] ?? [])
                }
            }
            healthStore.execute(query)
        }
    }
}
```

### 2. 上傳到 Workout V2 API
```swift
// 使用 Workout V2 API 上傳
func uploadAppleHealthWorkout(_ workout: HKWorkout) async throws {
    let workoutData = [
        "activity_profile": [
            "type": mapActivityType(workout.workoutActivityType),
            "start_time_utc": ISO8601DateFormatter().string(from: workout.startDate),
            "end_time_utc": ISO8601DateFormatter().string(from: workout.endDate),
            "duration_total_seconds": Int(workout.duration)
        ],
        "summary_metrics": [
            "distance_meters": workout.totalDistance?.doubleValue(for: .meter()),
            "active_calories_kcal": workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
            "avg_heart_rate_bpm": workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))
        ]
    ]
    
    let response = try await apiClient.post("/api/v1/workout/v2/workouts", data: workoutData)
    
    if response.success {
        print("✅ Workout uploaded successfully: \(response.data.id)")
    }
}
```

## 🏃 Garmin 資料同步

### 1. OAuth 授權流程
```typescript
// 發起 Garmin 授權
const initiateGarminAuth = async () => {
  const response = await fetch('/api/v1/connect/garmin/authorize', {
    headers: { 'Authorization': `Bearer ${accessToken}` }
  });
  
  const data = await response.json();
  
  if (data.success) {
    // 打開授權頁面
    window.open(data.data.authorization_url, '_blank');
    localStorage.setItem('oauth_state', data.data.state);
  }
};

// 處理授權回調
const handleGarminCallback = async (code: string, state: string) => {
  const savedState = localStorage.getItem('oauth_state');
  if (state !== savedState) {
    throw new Error('OAuth state mismatch');
  }
  
  const response = await fetch('/api/v1/connect/garmin/callback', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ code, state })
  });
  
  const result = await response.json();
  
  if (result.success) {
    showSuccessMessage('Garmin 連接成功！正在同步歷史數據...');
  }
};
```

### 2. 後台自動同步
- Garmin 資料會在後台自動同步
- 新運動完成後會透過 Webhook 即時推送
- 無需 App 主動拉取資料

## 📊 獲取 Workout 列表

### 1. 使用 Workout V2 API
```typescript
// 基本查詢
const fetchWorkouts = async (params: {
  page_size?: number;
  cursor?: string;
  start_date?: string;
  end_date?: string;
  activity_type?: string;
  provider?: 'garmin' | 'apple_health';
} = {}) => {
  const queryString = new URLSearchParams({
    page_size: params.page_size?.toString() || '20',
    ...params.cursor && { cursor: params.cursor },
    ...params.start_date && { start_date: params.start_date },
    ...params.end_date && { end_date: params.end_date },
    ...params.activity_type && { activity_type: params.activity_type },
    ...params.provider && { provider: params.provider }
  }).toString();
  
  const response = await fetch(`/api/v1/workout/v2/workouts?${queryString}`, {
    headers: { 'Authorization': `Bearer ${accessToken}` }
  });
  
  const data = await response.json();
  return data.data;
};

// 使用範例
const loadWorkouts = async () => {
  const result = await fetchWorkouts({
    page_size: 20,
    activity_type: 'running',
    start_date: '2024-12-01'
  });
  
  console.log('Workouts:', result.workouts);
  console.log('Next cursor:', result.pagination.next_cursor);
};
```

### 2. 回應格式
```json
{
  "success": true,
  "data": {
    "workouts": [
      {
        "id": "running_1750679253_5",
        "provider": "garmin",
        "activity_type": "running",
        "start_time_utc": "2024-12-25T06:00:00Z",
        "duration_seconds": 3600,
        "distance_meters": 10000,
        "basic_metrics": {
          "avg_heart_rate_bpm": 150,
          "avg_pace_per_km": "5:30",
          "total_calories": 500
        }
      }
    ],
    "pagination": {
      "next_cursor": "running_1750679253_5",
      "has_more": true,
      "total_estimated": 150
    }
  }
}
```

## 🔍 獲取 Workout 詳細內容

### 1. 使用 Workout V2 API
```typescript
const fetchWorkoutDetail = async (workoutId: string) => {
  const response = await fetch(`/api/v1/workout/v2/workouts/${workoutId}`, {
    headers: { 'Authorization': `Bearer ${accessToken}` }
  });
  
  const data = await response.json();
  return data.data;
};

// 使用範例
const showWorkoutDetail = async (workoutId: string) => {
  const workout = await fetchWorkoutDetail(workoutId);
  
  console.log('詳細資料:', {
    id: workout.id,
    provider: workout.provider,
    activityType: workout.activity_profile.type,
    startTime: workout.activity_profile.start_time_utc,
    duration: workout.activity_profile.duration_total_seconds,
    distance: workout.summary_metrics.distance_meters,
    avgHeartRate: workout.summary_metrics.avg_heart_rate_bpm,
    advancedMetrics: workout.advanced_metrics,
    timeSeries: workout.time_series_streams,
    route: workout.route_data
  });
};
```

### 2. 詳細資料結構
```json
{
  "success": true,
  "data": {
    "id": "running_1750679253_5",
    "schema_version": "2.0",
    "activity_profile": {
      "type": "running",
      "start_time_utc": "2024-12-25T06:00:00Z",
      "end_time_utc": "2024-12-25T07:00:00Z",
      "duration_total_seconds": 3600
    },
    "summary_metrics": {
      "distance_meters": 10000,
      "avg_heart_rate_bpm": 150,
      "max_heart_rate_bpm": 175,
      "active_calories_kcal": 500,
      "avg_pace_s_per_km": 330
    },
    "advanced_metrics": {
      "dynamic_vdot": 45.2,
      "tss": 65.8,
      "training_type": "tempo_run"
    },
    "time_series_streams": {
      "timestamps_seconds_offset": [0, 60, 120, ...],
      "heart_rate_bpm": [120, 125, 130, ...],
      "latitude_deg": [25.0330, 25.0331, ...],
      "longitude_deg": [121.5654, 121.5655, ...]
    },
    "route_data": {
      "total_points": 120,
      "coordinates": [
        {"lat": 25.0330, "lng": 121.5654, "timestamp": "2024-12-25T06:00:00Z"},
        {"lat": 25.0331, "lng": 121.5655, "timestamp": "2024-12-25T06:01:00Z"}
      ]
    }
  }
}
```

## 🔄 即時數據同步

### 1. Webhook 訂閱 (Garmin)
```typescript
const subscribeToWorkoutUpdates = async () => {
  const response = await fetch('/api/v1/webhooks/subscribe', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      webhook_url: 'https://your-app.com/webhook/workout-updates',
      events: ['workout.created', 'workout.updated']
    })
  });
  
  return response.json();
};
```

### 2. 推送通知處理
```typescript
// 在 App 中處理推送通知
const handleWorkoutNotification = (notification: {
  event: string;
  data: {
    workout_id: string;
    user_id: string;
    platform: string;
    activity_type: string;
  };
}) => {
  switch (notification.event) {
    case 'workout.created':
      showNotification('新的運動數據已同步！');
      refreshWorkoutList();
      break;
    case 'workout.updated':
      updateWorkoutInList(notification.data.workout_id);
      break;
  }
};
```

## 📱 UI/UX 最佳實踐

### 1. 連接狀態管理
```typescript
interface ConnectionStatus {
  platform: 'garmin' | 'apple_health';
  status: 'connected' | 'disconnected' | 'connecting' | 'error';
  lastSync?: string;
}

const ConnectionStatusCard: React.FC<{ connection: ConnectionStatus }> = ({ connection }) => {
  const getStatusColor = () => {
    switch (connection.status) {
      case 'connected': return 'green';
      case 'connecting': return 'yellow';
      case 'error': return 'red';
      default: return 'gray';
    }
  };
  
  return (
    <div className="connection-card">
      <div className="platform-info">
        <img src={`/icons/${connection.platform}.png`} alt={connection.platform} />
        <span>{connection.platform === 'garmin' ? 'Garmin' : 'Apple Health'}</span>
      </div>
      <div className={`status-indicator ${getStatusColor()}`}>
        {connection.status}
      </div>
      {connection.lastSync && (
        <div className="last-sync">
          最後同步: {formatRelativeTime(connection.lastSync)}
        </div>
      )}
    </div>
  );
};
```

### 2. 運動列表組件
```typescript
const WorkoutList: React.FC = () => {
  const [workouts, setWorkouts] = useState([]);
  const [loading, setLoading] = useState(false);
  const [cursor, setCursor] = useState(null);
  
  const loadWorkouts = async (refresh = false) => {
    setLoading(true);
    try {
      const result = await fetchWorkouts({
        page_size: 20,
        cursor: refresh ? null : cursor
      });
      
      if (refresh) {
        setWorkouts(result.workouts);
      } else {
        setWorkouts(prev => [...prev, ...result.workouts]);
      }
      
      setCursor(result.pagination.next_cursor);
    } finally {
      setLoading(false);
    }
  };
  
  return (
    <div className="workout-list">
      <PullToRefresh onRefresh={() => loadWorkouts(true)}>
        {workouts.map(workout => (
          <WorkoutCard key={workout.id} workout={workout} />
        ))}
      </PullToRefresh>
      
      {cursor && (
        <button onClick={() => loadWorkouts(false)} disabled={loading}>
          {loading ? '載入中...' : '載入更多'}
        </button>
      )}
    </div>
  );
};
```

## 🔧 錯誤處理

### 1. API 錯誤處理
```typescript
class WorkoutAPIClient {
  private async request<T>(url: string, options: RequestInit = {}): Promise<T> {
    const response = await fetch(url, {
      ...options,
      headers: {
        'Authorization': `Bearer ${this.accessToken}`,
        'Content-Type': 'application/json',
        ...options.headers
      }
    });
    
    if (!response.ok) {
      const error = await response.json();
      throw new APIError(error.error.code, error.error.message);
    }
    
    return response.json();
  }
  
  async fetchWorkouts(params: WorkoutQueryParams) {
    try {
      return await this.request('/api/v1/workout/v2/workouts', {
        method: 'GET'
      });
    } catch (error) {
      if (error instanceof APIError) {
        switch (error.code) {
          case 'INVALID_TOKEN':
            await this.refreshToken();
            return this.fetchWorkouts(params);
          case 'RATE_LIMIT_EXCEEDED':
            await this.delay(1000);
            return this.fetchWorkouts(params);
          default:
            throw error;
        }
      }
      throw error;
    }
  }
}
```

## 📋 整合檢查清單

### 基礎整合
- [ ] 實現 Garmin OAuth 授權流程
- [ ] 實現 Apple Health 數據上傳
- [ ] 使用 Workout V2 API 獲取運動列表
- [ ] 使用 Workout V2 API 獲取運動詳情
- [ ] 實現錯誤處理和重試機制

### 進階功能
- [ ] 實現資料來源切換
- [ ] 實現 Webhook 推送通知
- [ ] 實現分頁載入
- [ ] 實現下拉刷新
- [ ] 實現連接狀態顯示

### UI/UX 優化
- [ ] 載入狀態顯示
- [ ] 錯誤提示
- [ ] 空狀態處理
- [ ] 離線支援

## 🚀 快速開始

### 1. 環境配置
```typescript
// config/api.ts
export const API_CONFIG = {
  baseUrl: process.env.NODE_ENV === 'production' 
    ? 'https://api.paceriz.com' 
    : 'https://api-dev.paceriz.com',
  timeout: 10000
};
```

### 2. 基本使用範例
```typescript
// 1. 連接 Garmin
await initiateGarminAuth();

// 2. 上傳 Apple Health 數據
await uploadAppleHealthWorkout(workout);

// 3. 獲取運動列表
const workouts = await fetchWorkouts({ page_size: 20 });

// 4. 獲取運動詳情
const workout = await fetchWorkoutDetail(workoutId);
```

## 📞 技術支援

- **API 文檔**: https://docs.paceriz.com/api
- **技術支援**: support@paceriz.com
- **開發者社群**: https://community.paceriz.com

---

*最後更新: 2024-12-29*  
*版本: 2.0*  
*適用於: Workout V2 API* 
