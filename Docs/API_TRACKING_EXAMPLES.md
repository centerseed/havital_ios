# API 追蹤優雅使用方式

我們提供了**5 種**不同的 API 追蹤方式，從最簡潔到最靈活，選擇最適合你的！

---

## 方式一：`tracked()` 全局函數 ⭐ **推薦**

### 優點
- ✅ 語法簡潔清晰
- ✅ 類型安全
- ✅ 支援返回值
- ✅ 易於理解和維護

### 使用範例

```swift
struct TrainingPlanView: View {
    @StateObject private var viewModel = TrainingPlanViewModel()

    var body: some View {
        VStack {
            // UI content
        }
        .task {
            // ✨ 簡潔的語法
            await tracked("TrainingPlanView") {
                viewModel.loadAllInitialData()
            }
        }
        .refreshable {
            await tracked("TrainingPlanView") {
                viewModel.refreshWeeklyPlan()
            }
        }
    }
}
```

### Button 中使用

```swift
Button("刷新") {
    Task {
        await tracked("MyView") {
            viewModel.forceRefresh()
        }
    }
}
```

### 支援返回值

```swift
let result = await tracked("MyView") {
    viewModel.fetchData()  // 返回 Data
}
```

---

## 方式二：`~>` 運算符 ⚡ **最簡潔**

### 優點
- ✅ **超級簡潔**，一行搞定
- ✅ 視覺上清晰（來源 → 操作）
- ✅ 適合單行調用

### 缺點
- ⚠️ 自定義運算符可能影響可讀性
- ⚠️ 不適合複雜的多行操作

### 使用範例

```swift
struct MyAchievementView: View {
    var body: some View {
        VStack {
            // UI content
        }
        .task {
            // ✨ 超級簡潔！
            await "MyAchievementView" ~> trainingReadinessManager.loadData()
        }
    }
}
```

### Button 中使用

```swift
Button("刷新") {
    Task {
        await "MyView" ~> viewModel.refresh()
    }
}
```

### 多個 API 調用

```swift
.task {
    await "MyView" ~> viewModel.loadUserProfile()
    await "MyView" ~> viewModel.loadTrainingData()
    await "MyView" ~> viewModel.loadHealthData()
}
```

---

## 方式三：Protocol Extension 🎯 **最靈活**

### 優點
- ✅ 整個 View 統一使用同一來源
- ✅ 不用重複寫來源名稱
- ✅ 符合 Swift 協議導向設計

### 使用範例

```swift
struct UserProfileView: View, APISourceTrackable {
    var apiSource: String { "UserProfileView" }  // ✅ 只需定義一次

    @StateObject private var viewModel = UserProfileViewModel()

    var body: some View {
        VStack {
            // UI content
        }
        .task {
            // ✨ 不用寫來源名稱
            await withTracking {
                viewModel.fetchUserProfile()
            }
        }
        .refreshable {
            await withTracking {
                viewModel.fetchUserProfile()
            }
        }
    }

    private func deleteAccount() async {
        await withTracking {
            viewModel.deleteAccount()
        }
    }
}
```

### 多個方法共用同一來源

```swift
struct DataSyncView: View, APISourceTrackable {
    var apiSource: String { "DataSyncView" }

    func startSync() async {
        await withTracking {
            syncManager.startSync()
        }
    }

    func cancelSync() async {
        await withTracking {
            syncManager.cancelSync()
        }
    }
}
```

---

## 方式四：Task Extension 🔗 **鏈式調用**

### 優點
- ✅ 鏈式調用風格
- ✅ 適合已經在 Task 中的場景

### 缺點
- ⚠️ 只適用於 Task
- ⚠️ 語法較長

### 使用範例

```swift
struct TrainingRecordView: View {
    var body: some View {
        VStack {
            // UI content
        }
        .onAppear {
            Task {
                await viewModel.loadWorkouts()
            }.tracked(from: "TrainingRecordView")
        }
    }
}
```

---

## 方式五：Property Wrapper 📦 **重複使用**

### 優點
- ✅ 適合需要重複調用的函數
- ✅ 聲明式風格

### 缺點
- ⚠️ 語法較複雜
- ⚠️ 使用場景有限

### 使用範例

```swift
struct MyViewModel {
    @Tracked(source: "MyView")
    var loadData: () async -> Void = {
        await someAsyncOperation()
    }

    func callLoadData() async {
        try? await loadData()
    }
}
```

---

## 實際對比

### 同一個場景，5 種寫法對比

```swift
// ❌ 原始寫法（冗長）
.task {
    await APICallTracker.$currentSource.withValue("TrainingPlanView") {
        await viewModel.loadData()
    }
}

// ✅ 方式一：tracked() - 推薦
.task {
    await tracked("TrainingPlanView") {
        viewModel.loadData()
    }
}

// ⚡ 方式二：運算符 - 最簡潔
.task {
    await "TrainingPlanView" ~> viewModel.loadData()
}

// 🎯 方式三：Protocol - 最靈活
struct TrainingPlanView: View, APISourceTrackable {
    var apiSource: String { "TrainingPlanView" }

    var body: some View {
        VStack {}.task {
            await withTracking { viewModel.loadData() }
        }
    }
}

// 🔗 方式四：Task Extension
.onAppear {
    Task {
        await viewModel.loadData()
    }.tracked(from: "TrainingPlanView")
}
```

---

## 推薦使用指南

### 場景一：簡單的單個 API 調用
**推薦**：運算符 `~>` 或 `tracked()`

```swift
// 選項 A：超級簡潔
await "MyView" ~> viewModel.load()

// 選項 B：更明確
await tracked("MyView") { viewModel.load() }
```

### 場景二：多個連續的 API 調用
**推薦**：`tracked()` 包裹所有調用

```swift
await tracked("MyView") {
    viewModel.loadA()
    viewModel.loadB()
    viewModel.loadC()
}
```

### 場景三：整個 View 都用同一來源
**推薦**：`APISourceTrackable` Protocol

```swift
struct MyView: View, APISourceTrackable {
    var apiSource: String { "MyView" }

    // 所有地方都用 withTracking { }
}
```

### 場景四：Button 點擊
**推薦**：運算符 `~>` 最簡潔

```swift
Button("刷新") {
    Task {
        await "MyView" ~> viewModel.refresh()
    }
}
```

---

## 日誌輸出範例

所有方式的日誌輸出都相同：

```
📱 [API Call] TrainingPlanView → GET /plan/race_run/overview
   ├─ Accept-Language: en
   ├─ Body Size: 0 bytes
✅ [API End] TrainingPlanView → GET /plan/race_run/overview | 200 | 0.34s
```

---

## 完整範例：TrainingPlanView

### 使用 `tracked()` 函數

```swift
struct TrainingPlanView: View {
    @StateObject private var viewModel = TrainingPlanViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                // content
            }
            .refreshable {
                await tracked("TrainingPlanView") {
                    viewModel.refreshWeeklyPlan(isManualRefresh: true)
                }
            }
        }
        .onAppear {
            if viewModel.planStatus == .loading {
                await tracked("TrainingPlanView") {
                    refreshWorkouts()
                }
            }
        }
    }

    private func refreshWorkouts() {
        Task {
            await tracked("TrainingPlanView") {
                viewModel.loadAllInitialData()
            }
        }
    }
}
```

### 使用 `~>` 運算符

```swift
struct TrainingPlanView: View {
    @StateObject private var viewModel = TrainingPlanViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                // content
            }
            .refreshable {
                await "TrainingPlanView" ~> viewModel.refreshWeeklyPlan(isManualRefresh: true)
            }
        }
        .onAppear {
            if viewModel.planStatus == .loading {
                await "TrainingPlanView" ~> refreshWorkouts()
            }
        }
    }
}
```

### 使用 Protocol Extension

```swift
struct TrainingPlanView: View, APISourceTrackable {
    var apiSource: String { "TrainingPlanView" }

    @StateObject private var viewModel = TrainingPlanViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                // content
            }
            .refreshable {
                await withTracking {
                    viewModel.refreshWeeklyPlan(isManualRefresh: true)
                }
            }
        }
        .onAppear {
            await withTracking {
                if viewModel.planStatus == .loading {
                    refreshWorkouts()
                }
            }
        }
    }
}
```

---

## 我該選哪一種？

### 🥇 最推薦：`tracked()` 函數
- 清晰、簡潔、易維護
- 適合 95% 的場景

### 🥈 次推薦：`~>` 運算符
- 最簡潔的語法
- 適合單行調用

### 🥉 特殊場景：Protocol Extension
- 適合整個 View 統一管理
- 符合 Swift 設計風格

---

## 總結

所有方式都能正確追蹤 API 調用來源，選擇你覺得最舒服的即可！

**建議的實踐**：
1. 默認使用 `tracked()` 函數
2. 單行調用可以用 `~>` 運算符
3. 複雜的 View 考慮 Protocol Extension

開始使用吧！🚀
