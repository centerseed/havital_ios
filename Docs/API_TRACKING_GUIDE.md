# API 調用追蹤完整指南

## 概述

這個系統提供了**完整的 API 調用鏈追蹤**，從 View 發起到 HTTPClient 完成的全過程：

```
View (來源標記) → ViewModel → Manager → Service → HTTPClient (記錄完整日誌)
```

## 功能特性

✅ **完整調用鏈追蹤**：記錄從 View 到 API 的完整路徑
✅ **性能監控**：自動記錄每個 API 的耗時
✅ **錯誤追蹤**：詳細的錯誤日誌和調用來源
✅ **多種使用方式**：支援 modifier、helper function 和手動標記
✅ **線程安全**：基於 Swift TaskLocal 機制

---

## 使用方式

### 方式一：View Modifier（最簡單）✨ 推薦

為整個 View 自動追蹤所有 API 調用：

```swift
struct TrainingPlanView: View {
    @StateObject private var viewModel = TrainingPlanViewModel()

    var body: some View {
        VStack {
            // ... your UI code
        }
        .trackAPISource("TrainingPlanView")  // ✅ 一行搞定！
    }
}
```

**適用場景**：View 中所有 API 調用都來自同一來源

---

### 方式二：Helper Function（精確控制）

在特定操作中追蹤 API 來源：

```swift
struct MyAchievementView: View {
    var body: some View {
        VStack {
            Button("刷新") {
                Task {
                    await withAPITracking(source: "MyAchievementView") {
                        await viewModel.refresh()
                    }
                }
            }
        }
    }
}
```

**適用場景**：需要在按鈕點擊、手勢等特定事件中追蹤

---

### 方式三：手動包裹（最靈活）

手動控制追蹤範圍：

```swift
.task {
    await APICallTracker.$currentSource.withValue("TrainingRecordView") {
        await viewModel.loadWorkouts()
        await viewModel.loadStats()
    }
}

.refreshable {
    await APICallTracker.$currentSource.withValue("TrainingRecordView") {
        await viewModel.refreshWorkouts()
    }
}
```

**適用場景**：需要精確控制哪些操作被追蹤

---

## 日誌輸出格式

### 成功的 API 調用

```
📱 [API Call] TrainingPlanView → GET /plan/race_run/overview
   ├─ Accept-Language: en
   ├─ Body Size: 0 bytes
✅ [API End] TrainingPlanView → GET /plan/race_run/overview | 200 | 0.34s
```

### 失敗的 API 調用

```
📱 [API Call] UserProfileView → PUT /user
   ├─ Accept-Language: zh-Hant
   ├─ Body Size: 256 bytes
   └─ ❌ URL 錯誤: 請求超時 (2.05s)
💥 [API Error] UserProfileView → PUT /user | 請求超時
```

### 被取消的 API 調用

```
📱 [API Call] TrainingRecordView → GET /v2/workouts
   └─ ⚠️ 請求被取消 (0.12s)
```

---

## 實際範例

### 範例 1：TrainingPlanView（已實現）

```swift
struct TrainingPlanView: View {
    @StateObject private var viewModel = TrainingPlanViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                // UI content
            }
            .refreshable {
                await APICallTracker.$currentSource.withValue("TrainingPlanView") {
                    await viewModel.refreshWeeklyPlan(isManualRefresh: true)
                }
            }
        }
        .onAppear {
            Task {
                await APICallTracker.$currentSource.withValue("TrainingPlanView") {
                    if viewModel.planStatus == .loading {
                        refreshWorkouts()
                    }
                }
            }
        }
    }
}
```

**日誌輸出：**
```
📱 [API Call] TrainingPlanView → GET /plan/race_run/status
✅ [API End] TrainingPlanView → GET /plan/race_run/status | 200 | 0.21s

📱 [API Call] TrainingPlanView → GET /plan/race_run/weekly/plan_123_1
✅ [API End] TrainingPlanView → GET /plan/race_run/weekly/plan_123_1 | 200 | 0.45s
```

---

### 範例 2：MyAchievementView（使用 Helper）

```swift
struct MyAchievementView: View {
    @EnvironmentObject var trainingReadinessManager: TrainingReadinessManager

    var body: some View {
        ScrollView {
            VStack {
                Button("刷新") {
                    Task {
                        await withAPITracking(source: "MyAchievementView") {
                            await trainingReadinessManager.forceRefresh()
                        }
                    }
                }
            }
        }
        .onAppear {
            Task {
                await withAPITracking(source: "MyAchievementView") {
                    await trainingReadinessManager.loadData()
                }
            }
        }
    }
}
```

**日誌輸出：**
```
📱 [API Call] MyAchievementView → GET /training_readiness
✅ [API End] MyAchievementView → GET /training_readiness | 200 | 0.18s
```

---

### 範例 3：UserProfileView（多個 API 調用）

```swift
struct UserProfileView: View {
    @StateObject private var viewModel = UserProfileViewModel()

    var body: some View {
        ScrollView {
            // UI content
        }
        .task {
            await withAPITracking(source: "UserProfileView") {
                await viewModel.fetchUserProfile()  // → GET /user
                await viewModel.loadHeartRateZones()  // 本地計算，無 API
            }
        }
        .refreshable {
            await withAPITracking(source: "UserProfileView") {
                await viewModel.fetchUserProfile()
            }
        }
    }
}
```

**日誌輸出：**
```
📱 [API Call] UserProfileView → GET /user
✅ [API End] UserProfileView → GET /user | 200 | 0.28s
```

---

## 需要追蹤的關鍵 View 列表

### 高優先級（主要頁面）
- [x] **TrainingPlanView** - 訓練計劃（已實現）
- [ ] **MyAchievementView** - 成就/性能頁面
- [ ] **TrainingRecordView** - 訓練記錄列表
- [ ] **UserProfileView** - 用戶資料頁面
- [ ] **DataSyncView** - 數據同步頁面

### 中優先級（訓練相關）
- [ ] **WeeklySummaryView** - 週總結
- [ ] **WorkoutDetailViewV2** - 運動詳情
- [ ] **TrainingPlanOverviewDetailView** - 訓練總覽詳情
- [ ] **EditScheduleView** - 編輯課表

### 低優先級（其他功能）
- [ ] **VDOTChartView** - VDOT 圖表
- [ ] **HeartRateZoneEditorView** - 心率區間編輯
- [ ] **PerformanceChartView** - 表現圖表
- [ ] **OnboardingView** - 入門導覽

---

## 架構設計

### 調用流程

```
┌─────────────────┐
│  View (UI 觸發)  │
│  設置來源標記     │
└────────┬────────┘
         │ withAPITracking()
         ▼
┌─────────────────┐
│   ViewModel      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Manager       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Service       │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│      HTTPClient                  │
│  📱 記錄: 來源 → 方法 路徑       │
│  ✅ 記錄: 狀態碼、耗時           │
│  ❌ 記錄: 錯誤詳情               │
└─────────────────────────────────┘
```

### 技術實現

1. **TaskLocal 機制**
   - 線程安全的上下文傳播
   - 自動傳播到所有子任務
   - 不會影響其他並發任務

2. **性能追蹤**
   - 使用 `Date()` 記錄開始時間
   - 計算 API 調用總耗時
   - 精確到毫秒級別

3. **錯誤分類**
   - 網路錯誤（無連接、超時）
   - HTTP 錯誤（4xx、5xx）
   - 取消錯誤（用戶或系統取消）

---

## 遷移指南

### 從舊的 APICallContext 遷移

**舊寫法：**
```swift
await APICallContext.$currentSource.withValue("MyView") {
    await viewModel.load()
}
```

**新寫法（推薦）：**
```swift
await withAPITracking(source: "MyView") {
    await viewModel.load()
}
```

**或使用 Modifier：**
```swift
var body: some View {
    VStack { ... }
        .trackAPISource("MyView")
}
```

---

## 除錯技巧

### 查看完整的 API 調用鏈

在 Xcode Console 中搜尋：`[API`

你會看到：
```
📱 [API Call] ...      ← 調用開始
✅ [API End] ...       ← 調用成功
❌ [API Error] ...     ← 調用失敗
```

### 找出未標記來源的 API

搜尋：`Unknown →`

這些是還沒有設置來源標記的 API 調用。

### 性能分析

搜尋：`| 200 |` 然後查看耗時

找出耗時超過 1 秒的慢速 API：
```
✅ [API End] ... | 200 | 1.23s  ← 需要優化
```

---

## 常見問題

### Q: 為什麼我看到 "Unknown" 作為來源？

**A:** 該 View 還沒有使用 API 追蹤。請添加以下其中一種：
- `.trackAPISource("ViewName")` modifier
- `await withAPITracking(source: "ViewName") { ... }`

### Q: 在 Button 點擊中如何使用？

**A:** 使用 `Task` 包裹：
```swift
Button("刷新") {
    Task {
        await withAPITracking(source: "MyView") {
            await viewModel.refresh()
        }
    }
}
```

### Q: 如何追蹤多個連續的 API 調用？

**A:** 將它們都包在同一個 `withAPITracking` block 中：
```swift
await withAPITracking(source: "MyView") {
    await viewModel.loadA()  // API 1
    await viewModel.loadB()  // API 2
    await viewModel.loadC()  // API 3
}
```

### Q: 是否會影響性能？

**A:** 幾乎無影響。追蹤代碼只在 Debug 模式下輸出日誌，且使用異步方式不阻塞主線程。

---

## 最佳實踐

✅ **DO** - 在 View 的最頂層設置來源標記
✅ **DO** - 使用清晰的 View 名稱（如 "TrainingPlanView"）
✅ **DO** - 為所有會觸發 API 的 UI 操作添加追蹤
✅ **DO** - 定期檢查日誌中的 "Unknown" 來源

❌ **DON'T** - 在 ViewModel/Manager/Service 層設置來源
❌ **DON'T** - 使用縮寫或不清楚的名稱（如 "TPV"）
❌ **DON'T** - 為每個小函數都單獨設置來源

---

## 總結

使用這個 API 追蹤系統，你可以：

1. **清楚知道每個 API 是從哪個 View 發起的**
2. **監控 API 性能和耗時**
3. **快速定位錯誤來源**
4. **了解完整的調用鏈路**

開始在你的 View 中添加追蹤，享受清晰的 API 調用日誌吧！ 🚀
