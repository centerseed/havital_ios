# API 調用來源追蹤系統

## 功能說明
此系統讓你能在日誌中看到每個 API 調用是從哪個 View 發起的。

## 使用方法

### 標準用法：在 View 的 .task 中包裹 async 操作

```swift
struct TrainingPlanView: View {
    @StateObject private var viewModel = TrainingPlanViewModel()

    var body: some View {
        VStack {
            // ... your UI code
        }
        .task {
            // 使用 withValue 設置 API 調用來源
            await APICallContext.$currentSource.withValue("TrainingPlanView") {
                await viewModel.loadData()
            }
        }
    }
}
```

### 多個異步操作

```swift
struct ContentView: View {
    var body: some View {
        VStack {
            // ... your UI code
        }
        .task {
            await APICallContext.$currentSource.withValue("ContentView") {
                // 所有在此 block 內的 API 調用都會被標記為來自 ContentView
                await loadUserProfile()
                await loadTrainingOverview()
                await loadHealthData()
            }
        }
    }
}
```

### 在按鈕點擊等事件中使用

```swift
struct MyAchievementView: View {
    @StateObject private var viewModel = AchievementViewModel()

    var body: some View {
        VStack {
            Button("刷新") {
                Task {
                    await APICallContext.$currentSource.withValue("MyAchievementView") {
                        await viewModel.refresh()
                    }
                }
            }
        }
    }
}
```

## 日誌輸出格式

設置後，HTTPClient 會在每次 API 調用時輸出：

```
📱 [API Call] GET /v2/training_plan/weekly/123 | 來源: TrainingPlanView
📱 [API Call] POST /v2/workouts | 來源: ContentView
📱 [API Call] GET /v2/user/profile | 來源: UserProfileView
📱 [API Call] GET /v2/achievements | 來源: Unknown
                                              ^^^^^^^ 未設置來源
```

## 關鍵 View 列表（建議添加追蹤）

### 主要頁面
- `ContentView` - 主頁面
- `TrainingPlanView` - 訓練計劃
- `WeeklySummaryView` - 週總結
- `MyAchievementView` - 成就頁面

### 訓練相關
- `TrainingPlanOverviewView` - 訓練計劃總覽
- `TrainingRecordView` - 訓練記錄
- `TrainingItemDetailView` - 訓練項目詳情
- `WorkoutShareCardView` - 運動分享卡片

### 健康數據
- `PerformanceChartView` - 表現圖表
- `SleepHeartRateChartView` - 睡眠心率圖表
- `HRVTrendChartView` - HRV 趨勢圖表

### 設定與登入
- `UserProfileView` - 用戶資料
- `DataSyncView` - 數據同步
- `EmailLoginView` - 郵箱登入
- `OnboardingView` - 入門導覽

## 實作細節

### TaskLocal 機制
使用 Swift 的 `@TaskLocal` 機制，確保：
- 線程安全
- 自動傳播到子任務（async/await）
- 不會影響其他並發任務

### 架構層級
```
View (設置來源)
  ↓
ViewModel
  ↓
Manager
  ↓
Service
  ↓
HTTPClient (記錄來源) ✅ 日誌輸出在這裡
  ↓
Backend API
```

## 範例：為 TrainingPlanView 添加追蹤

**修改前：**
```swift
struct TrainingPlanView: View {
    @StateObject private var viewModel = TrainingPlanViewModel()

    var body: some View {
        VStack {
            // UI code
        }
        .task {
            await viewModel.loadAllInitialData()
        }
    }
}
```

**修改後：**
```swift
struct TrainingPlanView: View {
    @StateObject private var viewModel = TrainingPlanViewModel()

    var body: some View {
        VStack {
            // UI code
        }
        .task {
            await APICallContext.$currentSource.withValue("TrainingPlanView") {
                await viewModel.loadAllInitialData()
            }
        }
    }
}
```

## 注意事項

1. **只在 View 層設置來源**：不要在 ViewModel/Manager/Service 層設置
2. **使用 withValue**：確保使用 `APICallContext.$currentSource.withValue("ViewName") { ... }`
3. **命名規範**：使用完整的 View 名稱（例如："TrainingPlanView" 而非 "TrainingPlan"）
4. **範圍控制**：只包裹需要追蹤的 async 操作

## 測試驗證

運行 app 後，查看 Xcode Console，應該看到：

```
📱 [API Call] GET /v2/training_plan/overview | 來源: ContentView
📱 [API Call] GET /v2/training_plan/weekly/plan_123_1 | 來源: TrainingPlanView
📱 [API Call] POST /v2/workouts/sync | 來源: DataSyncView
```

如果看到 `來源: Unknown`，表示該 API 調用的發起 View 尚未設置來源標記。
