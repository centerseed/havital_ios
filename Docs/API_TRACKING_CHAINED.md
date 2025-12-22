# API 調用追蹤 - 鏈式調用指南

## 推薦方式: `.tracked(from:)` 鏈式調用 ⭐

### 為什麼選擇這個方式?

✅ **語意清晰**: `tracked(from: "ViewName: functionName")` 精確記錄調用位置
✅ **不侵入代碼**: 只需在 Task 後加一行,不影響原有邏輯
✅ **易於追蹤**: 日誌清楚顯示從哪個 View 的哪個函數觸發 API
✅ **支援返回值**: 使用 `.value` 可以獲取 Task 返回值

---

## 基本語法

### 無返回值的 Task
```swift
Task {
    await viewModel.loadData()
}.tracked(from: "ViewName: functionName")
```

### 帶返回值的 Task
```swift
let result = await Task {
    return await viewModel.fetchData()
}.tracked(from: "ViewName: functionName").value
```

---

## 實際使用範例

### 1. Button 點擊

```swift
Button("刷新") {
    Task {
        await viewModel.refresh()
    }.tracked(from: "TrainingPlanView: refresh")
}

Button("重試") {
    Task {
        await viewModel.retryNetworkRequest()
    }.tracked(from: "TrainingPlanView: retryNetworkRequest")
}
```

### 2. .refreshable 下拉刷新

```swift
.refreshable {
    await Task {
        await viewModel.refreshWeeklyPlan(isManualRefresh: true)
    }.tracked(from: "TrainingPlanView: refreshWeeklyPlan").value
}
```

**注意**: `.refreshable` 需要返回值,所以要加 `.value`

### 3. 私有函數中的 Task

```swift
private func refreshWorkouts() {
    Logger.debug("Refreshing training records and weekly volume")
    Task {
        await viewModel.loadPlanStatus()
        await viewModel.refreshWeeklyPlan()
        await viewModel.loadCurrentWeekDistance()
        await viewModel.loadWorkoutsForCurrentWeek()
    }.tracked(from: "TrainingPlanView: refreshWorkouts")
}
```

### 4. .onReceive 通知處理

```swift
.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
    Task {
        await viewModel.loadData()
    }.tracked(from: "TrainingPlanView: willEnterForeground")
}
```

### 5. Callback 閉包

```swift
AdjustmentConfirmationView(
    initialItems: viewModel.pendingAdjustments,
    summaryId: viewModel.pendingSummaryId ?? "unknown",
    onConfirm: { selectedItems in
        Task {
            await viewModel.confirmAdjustments(selectedItems)
        }.tracked(from: "TrainingPlanView: confirmAdjustments")
    }
)
```

### 6. 錯誤重試

```swift
ErrorView(error: error) {
    Task {
        await viewModel.loadWeeklyPlan()
    }.tracked(from: "TrainingPlanView: loadWeeklyPlan")
}

WeeklySummaryErrorView(error: error) {
    Task {
        await viewModel.retryCreateWeeklySummary()
    }.tracked(from: "TrainingPlanView: retryCreateWeeklySummary")
}
```

### 7. Alert 中的重試

```swift
.alert(NSLocalizedString("error.network", comment: "Network Connection Error"),
       isPresented: $viewModel.showNetworkErrorAlert) {
    Button(NSLocalizedString("common.retry", comment: "Retry")) {
        Task {
            await viewModel.retryNetworkRequest()
        }.tracked(from: "TrainingPlanView: retryNetworkRequest")
    }
}
```

### 8. Sheet 中的操作

```swift
.sheet(isPresented: $viewModel.showWeeklySummary) {
    WeeklySummaryView(
        summary: summary,
        onGenerateNextWeek: {
            Task {
                let targetWeek = viewModel.pendingTargetWeek ?? viewModel.currentWeek
                viewModel.showWeeklySummary = false

                if hasPendingWeek {
                    await viewModel.confirmAdjustmentsAndGenerateNextWeek(targetWeek: targetWeek)
                } else {
                    await viewModel.generateNextWeekPlan(targetWeek: targetWeek)
                }
            }.tracked(from: "TrainingPlanView: generateNextWeek")
        }
    )
}
```

---

## 日誌輸出範例

### 輸入代碼
```swift
private func refreshWorkouts() {
    Task {
        await viewModel.loadPlanStatus()
        await viewModel.refreshWeeklyPlan()
    }.tracked(from: "TrainingPlanView: refreshWorkouts")
}
```

### 日誌輸出
```
📱 [API Call] TrainingPlanView: refreshWorkouts → GET /plan/race_run/status
   ├─ Accept-Language: en
   ├─ Body Size: 0 bytes
✅ [API End] TrainingPlanView: refreshWorkouts → GET /plan/race_run/status | 200 | 0.34s

📱 [API Call] TrainingPlanView: refreshWorkouts → GET /plan/race_run/weekly/plan_123_1
   ├─ Accept-Language: en
   ├─ Body Size: 0 bytes
✅ [API End] TrainingPlanView: refreshWorkouts → GET /plan/race_run/weekly/plan_123_1 | 200 | 0.45s
```

**優點**: 清楚看到這兩個 API 都是從 `TrainingPlanView` 的 `refreshWorkouts` 函數觸發的

---

## 命名慣例

### 基本格式
```swift
"ViewName: functionName"
```

### 具體範例
```swift
"TrainingPlanView: refreshWorkouts"
"TrainingPlanView: loadWeeklyPlan"
"TrainingPlanView: createWeeklySummary"
"TrainingPlanView: confirmAdjustments"
"UserProfileView: fetchProfile"
"MyAchievementView: loadData"
```

### 特殊情況

#### 多個相似操作
```swift
"TrainingPlanView: retryNetworkRequest"
"TrainingPlanView: retryCreateWeeklySummary"
```

#### 通知處理
```swift
"TrainingPlanView: willEnterForeground"
"TrainingPlanView: onboardingCompleted"
```

#### 子視圖
```swift
"FinalWeekPromptView: createWeeklySummary"
"NewWeekPromptView: createWeeklySummary"
```

---

## 常見錯誤與解決

### ❌ 錯誤 1: 忘記加 .tracked()
```swift
// ❌ 沒有追蹤
Button("刷新") {
    Task {
        await viewModel.refresh()
    }
}
```

```swift
// ✅ 正確追蹤
Button("刷新") {
    Task {
        await viewModel.refresh()
    }.tracked(from: "TrainingPlanView: refresh")
}
```

### ❌ 錯誤 2: .refreshable 忘記加 .value
```swift
// ❌ 編譯錯誤 - refreshable 需要返回值
.refreshable {
    await Task {
        await viewModel.refresh()
    }.tracked(from: "TrainingPlanView: refresh")
}
```

```swift
// ✅ 正確 - 加上 .value
.refreshable {
    await Task {
        await viewModel.refresh()
    }.tracked(from: "TrainingPlanView: refresh").value
}
```

### ❌ 錯誤 3: 命名不清晰
```swift
// ❌ 太簡略
.tracked(from: "TPV")
.tracked(from: "refresh")
```

```swift
// ✅ 清晰明確
.tracked(from: "TrainingPlanView: refresh")
.tracked(from: "TrainingPlanView: refreshWorkouts")
```

---

## 其他追蹤方式對比

### 方式 1: 包裝函數 `tracked()`
```swift
await tracked("TrainingPlanView") {
    viewModel.loadData()
}
```
**缺點**: 需要包裝整個代碼塊,語法較冗長

### 方式 2: 運算符 `~>`
```swift
await "TrainingPlanView" ~> viewModel.loadData()
```
**缺點**: 不適合多行代碼,無法指定函數名

### 方式 3: Protocol Extension
```swift
struct TrainingPlanView: View, APISourceTrackable {
    var apiSource: String { "TrainingPlanView" }

    func refresh() async {
        await withTracking { viewModel.refresh() }
    }
}
```
**缺點**: 無法指定函數名,需要實現 protocol

### 方式 4: 鏈式調用 `.tracked(from:)` ⭐ 推薦
```swift
Task {
    await viewModel.refresh()
}.tracked(from: "TrainingPlanView: refresh")
```
**優點**:
- 語意清晰,可以指定 View 和函數名
- 不侵入原有代碼結構
- 支援返回值
- 適合所有場景

---

## 最佳實踐總結

1. **統一格式**: 使用 `"ViewName: functionName"` 格式
2. **清晰命名**: 避免縮寫,使用完整的 View 名稱
3. **精確定位**: 記錄具體的觸發函數,不只是 View 名稱
4. **全面覆蓋**: 為所有 API 相關的 Task 添加追蹤
5. **及時添加**: 在寫新代碼時就加上,避免遺漏

---

## 技術實現

追蹤系統基於 Swift 的 `@TaskLocal` 機制,自動在 async context 中傳播:

```swift
extension Task where Success == Void, Failure == Never {
    func tracked(from source: String) -> Task {
        Task {
            await APICallTracker.$currentSource.withValue(source) {
                await self.value
            }
        }
    }
}

extension Task {
    func tracked(from source: String) -> Task {
        Task {
            await APICallTracker.$currentSource.withValue(source) {
                await self.value
            }
        }
    }
}
```

詳細實現請參考: `Havital/Utils/APISourceTracking.swift`

---

## 相關文檔

- `CLAUDE.md` - 項目架構指南（已包含 API 追蹤章節）
- `APISourceTracking.swift` - 追蹤系統實現
- `API_TRACKING_EXAMPLES.md` - 5 種使用方式詳細對比
- `API_TRACKING_GUIDE.md` - 原始追蹤系統指南
- `HTTPClient.swift` - HTTP 層的日誌實現

---

**開始使用**: 為你的 View 中的所有 Task 添加 `.tracked(from:)`,享受清晰的 API 調用追蹤! 🚀
