# Paceriz iOS App

## Project Overview
Paceriz is a fitness tracking application supporting Apple Health and Garmin Connect integration with comprehensive training plan management.

**Important**: Product name is **Paceriz**, while technical identifiers (Bundle ID, Background Task IDs) remain as `com.havital.*` for App Store continuity.

## Project Structure
- `Havital/Managers/` - Core business logic (UserManager, UnifiedWorkoutManager, etc.)
- `Havital/ViewModels/` - UI state management with TaskManageable protocol
- `Havital/Services/` - API communication layer
- `Havital/Views/` - SwiftUI views organized by feature
- `Havital/Storage/` - Local data persistence and caching

**Note**: Directory names remain as `Havital` for technical reasons, but all user-facing content uses **Paceriz**.

## Core Architecture Principles

### 1. Initialization Order (CRITICAL)
**Strict sequence must be followed to prevent crashes and UI errors:**

```
App Launch → User Authentication → User Data Loading → Training Overview → Weekly Plan → UI Ready
```

**❌ Problem**: TrainingPlanViewModel initializing before user data is ready causes "cancelled" errors
**✅ Solution**: Always wait for user authentication and data loading completion

```swift
// ✅ CORRECT - Wait for user data before training data
class TrainingPlanViewModel: ObservableObject, @preconcurrency TaskManageable {
    init() {
        Task {
            await waitForUserDataReady() // CRITICAL: Wait first
            await loadTrainingData()
        }
    }
    
    private func waitForUserDataReady() async {
        while !AuthenticationService.shared.isAuthenticated {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}
```

### 2. Task Management & Cancellation Handling

#### TaskManageable Protocol Implementation
```swift
// ✅ CORRECT - Thread-safe task management
class MyViewModel: ObservableObject, @preconcurrency TaskManageable {
    let taskRegistry = TaskRegistry()
    
    func loadData() async {
        await executeTask(id: TaskID("load_data")) { [weak self] in
            // API calls here
        }
    }
    
    deinit { cancelAllTasks() }
}
```

#### Critical: Handle Task Cancellation Properly
**Common Issue**: "cancelled" errors showing ErrorView incorrectly

```swift
// ✅ CORRECT - Ignore cancellation errors
} catch {
    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
        Logger.debug("Task cancelled, ignoring error")
        return // Don't update UI state for cancelled tasks
    }
    
    // Handle real errors
    await updateUI(error: error)
}
```

### 3. UI State Management Pattern

#### PlanStatus Enum for TrainingPlanView
```swift
enum PlanStatus: Equatable {
    case loading
    case noPlan        // Show "Generate Weekly Review" button
    case ready(WeeklyPlan)  // Show plan content
    case completed     // Show final week prompt
    case error(Error)  // Show ErrorView - ONLY for real errors
}
```

**Critical Rules:**
- `.error` state should ONLY be used for actionable errors
- `.noPlan` state preserves weekly review functionality
- Never set `.error` for cancelled tasks

### 4. Data Flow Architecture

#### Correct API-First Pattern
```
User Authentication → Backend API → Local Storage → UI Updates
```

**NEVER**: HealthKit → UI (bypassing backend)
**ALWAYS**: HealthKit → Backend API → WorkoutV2 Models → UI

#### Manager Layer Standards
```swift
// ✅ CORRECT - DataManageable with proper error handling
class TrainingPlanManager: ObservableObject, @preconcurrency TaskManageable {
    let taskRegistry = TaskRegistry()
    
    func loadWeeklyPlan() async {
        await executeDataLoadingTask(id: TaskID("load_weekly_plan")) {
            guard let overview = trainingOverview, !overview.id.isEmpty else {
                await loadTrainingOverview() // Auto-retry missing dependencies
                guard trainingOverview != nil else {
                    return .noPlan // Graceful degradation
                }
            }
            
            let plan = try await TrainingPlanService.shared.getWeeklyPlanById(
                planId: "\(overview.id)_\(currentWeek)"
            )
            return .ready(plan)
        }
    }
}
```

### 5. Critical Dictionary Safety

#### FORBIDDEN Patterns (Cause Crashes)
```swift
// ❌ FORBIDDEN - Date objects as Dictionary keys
let grouped = Dictionary(grouping: workouts) { workout in
    workout.date  // CRASH RISK - Date as key
}

// ❌ FORBIDDEN - Mixed key types
var cache: [String: Data] = [:]
cache[someDate.description] = data  // CRASH RISK
```

#### REQUIRED Safe Patterns
```swift
// ✅ REQUIRED - TimeInterval as keys
let grouped = Dictionary(grouping: workouts) { workout in
    workout.date.timeIntervalSince1970  // SAFE - Primitive type
}

// ✅ REQUIRED - TaskID for task management
var activeTasks: [TaskID: Task<Void, Never>] = [:]
```

### 6. API 服務架構原則

#### 職責分離架構 (Separation of Concerns)
```
📱 UI Layer (Views)
    ↓ 觸發操作
🧠 ViewModel Layer (TaskManageable)
    ↓ 業務協調
📊 Manager Layer (TaskManageable + 雙軌緩存)
    ↓ 數據管理
🔄 Service Layer (業務 API 包裝)
    ↓ API 調用
🌐 HTTPClient (純 HTTP 通信)
📋 APIParser (JSON 解析)
💾 Storage Layer (本地緩存)
```

#### 雙軌緩存策略 (Cache-First with Background Refresh)
**核心原則**: 立即顯示緩存內容，同時在背景更新數據

```swift
// ✅ CORRECT - 雙軌數據載入
func loadWeeklyPlan() async {
    await executeTask(id: TaskID("load_weekly_plan")) { [weak self] in
        guard let self = self else { return }
        
        // 軌道 A: 立即顯示緩存 (同步)
        if let cachedPlan = storage.getCachedPlan() {
            await self.updateUI(with: .ready(cachedPlan))
        }
        
        // 軌道 B: 背景更新 (非同步)
        Task.detached { [weak self] in
            await self?.refreshDataInBackground()
        }
    }
}

private func refreshDataInBackground() async {
    await executeTask(id: TaskID("refresh_weekly_plan")) { [weak self] in
        let latestPlan = try await service.getWeeklyPlanById(planId)
        self?.storage.savePlan(latestPlan)
        await self?.updateUI(with: .ready(latestPlan))
    }
}
```

#### API 層職責定義
| 層級 | 職責 | 不負責 |
|------|------|--------|
| **HTTPClient** | HTTP 通信、認證、網路錯誤 | JSON 解析、業務邏輯 |
| **APIParser** | JSON 解析、類型轉換、解析錯誤 | HTTP 通信、業務邏輯 |
| **Service** | API 調用包裝、業務錯誤處理 | 緩存管理、UI 狀態 |
| **Manager** | 緩存策略、業務邏輯協調 | 具體 API 實現 |

#### 統一解析模式
```swift
protocol APIParser {
    func parse<T: Codable>(_ type: T.Type, from data: Data) throws -> T
}

// ✅ CORRECT - Model 驅動的解析
let response: WorkoutListResponse = try parser.parse(
    WorkoutListResponse.self, 
    from: jsonData
)
```

#### 任務管理最佳實踐

##### 1. 標準化任務命名
```swift
// ✅ CORRECT - 具有唯一性的任務 ID
TaskID("load_weekly_plan_\(week)")          // 包含參數的唯一 ID
TaskID("background_refresh_overview")        // 背景任務
TaskID("generate_new_week_\(selectedWeek)")  // 具有副作用的操作
```

##### 2. 雙軌載入實現模式
```swift
// ✅ CORRECT - 完整的雙軌緩存實現
class DataManager: ObservableObject, @preconcurrency TaskManageable {
    let taskRegistry = TaskRegistry()
    
    func loadData() async {
        await executeTask(id: TaskID("load_data_\(identifier)")) { [weak self] in
            guard let self = self else { return }
            
            // 軌道 A: 立即顯示緩存 (同步)
            if let cachedData = cache.loadData() {
                await MainActor.run {
                    self.data = cachedData
                    self.isLoading = false
                }
                
                // 軌道 B: 背景更新 (非同步)
                Task.detached { [weak self] in
                    await self?.executeTask(id: TaskID("background_refresh_\(identifier)")) {
                        await self?.refreshInBackground()
                    }
                }
                return
            }
            
            // 沒有緩存時直接從 API 載入
            let freshData = try await service.fetchData()
            await MainActor.run { self.data = freshData }
            cache.saveData(freshData)
        }
    }
    
    private func refreshInBackground() async {
        do {
            let latestData = try await service.fetchData()
            await MainActor.run { self.data = latestData }
            cache.saveData(latestData)
        } catch {
            // 背景更新失敗不影響已顯示的緩存
            Logger.debug("背景更新失敗，保持現有緩存: \(error.localizedDescription)")
        }
    }
}
```

##### 3. 取消錯誤處理標準
```swift
// ✅ CORRECT - 標準化的取消錯誤處理
} catch {
    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
        Logger.debug("任務被取消，忽略錯誤")
        return // 不更新 UI 狀態
    }
    
    // 處理真實錯誤
    await MainActor.run { self.syncError = error.localizedDescription }
    Logger.error("操作失敗: \(error.localizedDescription)")
}
```

##### 4. 任務優先級管理
- **高優先級**: UI 相關的數據載入 (使用 `executeTask`)  
- **低優先級**: 背景更新 (使用 `Task.detached`)
- **防重複**: 相同 TaskID 不會重複執行

### 7. API 調用追蹤系統 (API Call Tracking)

#### 核心原則
使用 **鏈式調用 `.tracked(from:)`** 追蹤每個 API 調用的來源 View 和觸發的函數,確保日誌清晰且易於除錯。

#### 推薦語法: 鏈式調用 `.tracked(from:)` ⭐

**語意清晰**: `tracked(from: "ViewName: functionName")` 精確記錄調用位置

```swift
// ✅ CORRECT - 鏈式調用,語意清晰
struct TrainingPlanView: View {
    var body: some View {
        VStack {
            Button("刷新") {
                Task {
                    await viewModel.refresh()
                }.tracked(from: "TrainingPlanView: refresh")
            }
        }
        .refreshable {
            await Task {
                await viewModel.refreshWeeklyPlan()
            }.tracked(from: "TrainingPlanView: refreshWeeklyPlan").value
        }
    }

    private func refreshWorkouts() {
        Task {
            await viewModel.loadPlanStatus()
            await viewModel.refreshWeeklyPlan()
            await viewModel.loadCurrentWeekDistance()
        }.tracked(from: "TrainingPlanView: refreshWorkouts")
    }
}
```

#### 日誌輸出格式
系統會在 HTTPClient 層自動記錄完整的 API 調用鏈:

```
📱 [API Call] TrainingPlanView: refreshWorkouts → GET /plan/race_run/status
   ├─ Accept-Language: en
   ├─ Body Size: 0 bytes
✅ [API End] TrainingPlanView: refreshWorkouts → GET /plan/race_run/status | 200 | 0.34s

📱 [API Call] TrainingPlanView: refreshWorkouts → GET /plan/race_run/weekly/plan_123_1
✅ [API End] TrainingPlanView: refreshWorkouts → GET /plan/race_run/weekly/plan_123_1 | 200 | 0.45s
```

#### 使用場景

##### 1. Button 點擊
```swift
Button("重試") {
    Task {
        await viewModel.retryNetworkRequest()
    }.tracked(from: "TrainingPlanView: retryNetworkRequest")
}
```

##### 2. .refreshable 下拉刷新
```swift
.refreshable {
    await Task {
        await viewModel.refreshWeeklyPlan(isManualRefresh: true)
    }.tracked(from: "TrainingPlanView: refreshWeeklyPlan").value
}
```

##### 3. 私有函數中的 Task
```swift
private func refreshWorkouts() {
    Task {
        await viewModel.loadPlanStatus()
        await viewModel.refreshWeeklyPlan()
    }.tracked(from: "TrainingPlanView: refreshWorkouts")
}
```

##### 4. Callback 閉包
```swift
onConfirm: { selectedItems in
    Task {
        await viewModel.confirmAdjustments(selectedItems)
    }.tracked(from: "TrainingPlanView: confirmAdjustments")
}
```

##### 5. 帶返回值的 Task
```swift
let result = await Task {
    return await viewModel.fetchData()
}.tracked(from: "UserProfileView: fetchData").value
```

#### 實現細節
詳細文檔請參考:
- `Havital/Utils/APISourceTracking.swift` - 追蹤系統實現
- `Docs/API_TRACKING_EXAMPLES.md` - 5 種使用方式對比
- `Docs/API_TRACKING_GUIDE.md` - 完整使用指南

### 8. Debugging & Logging Strategy

#### Essential Debug Information
```swift
// ✅ Add comprehensive logging for async operations
Logger.debug("TrainingPlanViewModel: 開始初始化")
Logger.debug("等待用戶資料載入完成...")
Logger.debug("API 調用: planId=\(planId)")
Logger.debug("成功載入: \(plan.id)")

// ✅ Track error context
Logger.error("載入失敗: \(error.localizedDescription)")
if error.isCancelled {
    Logger.debug("任務被取消，忽略錯誤")
    return
}
```

## Common Antipatterns & Solutions

### ⚠️ Problem: Multiple Initialization Paths
**Symptom**: "TrainingPlanViewModel.loadAllInitialData" vs "init()" conflict
**Solution**: Single initialization pathway with proper sequencing

### ⚠️ Problem: ErrorView Showing for Cancelled Tasks  
**Symptom**: User sees error screen after successful data load
**Solution**: Filter out cancellation errors before updating UI state

### ⚠️ Problem: Race Conditions in Data Loading
**Symptom**: Tasks executing out of order, causing inconsistent state
**Solution**: Use TaskRegistry to prevent duplicate executions + proper dependency management

## Pre-Deployment Checklist

### Mandatory Code Review Points
- [ ] No Date objects as Dictionary keys (`grep -r "Dictionary.*Date"`)
- [ ] All TaskManageable classes handle cancellation (`cancelled` error check)
- [ ] Initialization waits for user data readiness
- [ ] ErrorView only shows for actionable errors
- [ ] All async closures use `[weak self]`
- [ ] Comprehensive logging for debugging race conditions

### Testing Commands
```bash
# Clean build with thread safety validation
cd "/Users/wubaizong/havital/apps/ios/Havital"
xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 16'

# Search for crash patterns
grep -r "Dictionary.*Date" Havital/ --include="*.swift"
grep -r "var activeTasks.*String:" Havital/ --include="*.swift"
grep -r "catch.*{" Havital/ --include="*.swift" | grep -v "cancelled"
```

### Runtime Validation
1. **Test initialization race conditions**: Kill and restart app multiple times
2. **Verify ErrorView triggers**: Should only appear for network/API errors
3. **Check task cancellation**: Monitor logs for proper cancellation handling
4. **Validate data flow**: User auth → Training overview → Weekly plan sequence

## Architecture Success Metrics
- **Zero Dictionary crash reports**: No `removeValue` failures
- **Proper error display**: ErrorView only for actionable errors
- **Initialization reliability**: Consistent data loading regardless of timing
- **Task management efficiency**: No memory leaks from uncancelled tasks

---

**Key Principle**: Every async operation must handle cancellation gracefully and maintain correct UI state transitions.