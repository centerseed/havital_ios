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

### 0.1. Clean Architecture 設計原則 (最高設計原則)

本專案採用 **Clean Architecture** 四層架構設計，確保代碼的可維護性、可測試性和可擴展性。

#### 四層架構概覽

```
Presentation Layer (外層)
    ↓ 依賴
Domain Layer (業務核心)
    ↓ 依賴
Data Layer (數據實作)
    ↓ 依賴
Core Layer (基礎設施)
```

**核心原則**: 依賴方向永遠向內（外層 → 內層），內層不知道外層的存在。

#### 各層職責與組件

**Presentation Layer (呈現層)**
- **職責**: UI 渲染、用戶交互、狀態綁定
- **組件**: Views (SwiftUI), ViewModels (@Published state), ViewState enums
- **禁止**: 業務邏輯、直接 API 調用、直接數據庫訪問
- **原則**: View 只顯示數據，ViewModel 只管理 UI 狀態

**Domain Layer (領域層)**
- **職責**: 業務實體定義、業務規則、數據訪問介面定義
- **組件**: Entities (業務模型), Repository Protocols (介面定義), UseCases (可選)
- **禁止**: 依賴外層 (Presentation)、依賴實作細節 (Data Layer)
- **原則**: 定義"做什麼"，不定義"怎麼做"

**Data Layer (數據層)**
- **職責**: Repository 實作、API 調用、緩存管理、DTO ↔ Entity 轉換
- **組件**: RepositoryImpl, RemoteDataSource, LocalDataSource, DTOs, Mappers
- **禁止**: 業務邏輯、UI 狀態管理
- **原則**: 實現雙軌緩存策略，協調遠端與本地數據源

**Core Layer (核心層)**
- **職責**: 網路通訊、緩存基礎設施、事件系統、依賴注入、工具函式
- **組件**: HTTPClient, UnifiedCacheManager, CacheEventBus, DependencyContainer, Logger
- **禁止**: 業務邏輯、UI 相關代碼
- **原則**: 提供抽象基礎設施，供上層使用

#### 關鍵設計模式

**1. Repository Pattern (倉庫模式)**

- Domain Layer 定義 Repository **Protocol** (介面)
- Data Layer 實作 Repository **Implementation** (具體實現)
- ViewModel 依賴 Protocol，不依賴具體實作
- 符合依賴反轉原則 (Dependency Inversion Principle)

**流程**:
```
ViewModel → Repository Protocol (Domain) → RepositoryImpl (Data) → RemoteDataSource/LocalDataSource
```

**2. ViewState Enum Pattern (統一狀態管理)**

- 使用泛型 `ViewState<T>` 枚舉統一管理 UI 狀態
- 取代多個散亂的 `@Published` 屬性
- 狀態類型: `.loading`, `.loaded(data)`, `.error(error)`, `.empty`
- 確保 UI 狀態明確且易於測試

**3. Dual-Track Caching Strategy (雙軌緩存策略)**

雙軌緩存根據場景採用不同策略：

**正常載入場景**:
- Track A: 立即返回本地緩存（快速顯示）
- Track B: 背景刷新 API 數據（保持新鮮）
- 用戶立即看到內容，數據在背景更新

**特殊刷新場景**（如 Onboarding 完成、用戶登出）:
- 清除所有緩存
- 強制從 API 重新載入
- 確保顯示最新狀態

**實現位置**: Data Layer 的 RepositoryImpl 負責協調兩個 Track

**4. CacheEventBus (事件通訊系統)**

**目的**: 提供符合 Clean Architecture 的應用程式級事件訂閱/發布機制

**核心價值**:
- 避免直接使用 `NotificationCenter.default`（違反依賴反轉原則）
- 各層依賴抽象事件協議，而非具體通知系統
- 支援雙軌緩存的特殊場景處理（如 Onboarding 完成需清除緩存）

**事件類型範例**:
- `.userLogout`: 清除所有用戶緩存
- `.trainingPlanUpdated`: 刷新訓練計畫視圖
- `.onboardingCompleted`: 重新載入初始數據

**事件流程**:
```
事件發布 → CacheEventBus.publish(.eventType)
    ↓
訂閱者響應 → ViewModel/Manager 執行業務邏輯
    ↓
緩存清除 → Repository.clearCache()
    ↓
強制刷新 → Repository.forceRefreshFromAPI()
    ↓
UI 更新 → ViewModel.state = .loaded(newData)
```

**發布者與訂閱者位置原則**:

核心設計規則:
1. **誰負責操作誰發布**: 執行業務操作的層級負責發布相應事件
2. **誰需要響應誰訂閱**: 需要更新狀態的組件訂閱相關事件
3. **Repository 是被動的**: Repository 層永遠不發布事件，也不訂閱事件

訂閱者位置:
- ✅ **主要**: Presentation Layer (ViewModels) - 訂閱事件更新 UI 狀態
- ✅ **次要**: Domain/Data Layer (Managers/Services) - 訂閱事件執行業務邏輯
- ❌ **禁止**: Repository/DataSource - 違反被動原則

發布者位置:
- ✅ **允許**: Presentation Layer (Coordinators/ViewModels) - 完成流程後發布事件
- ✅ **允許**: Domain/Data Layer (Services/Managers) - 業務操作完成後發布事件
- ❌ **禁止**: Repository/DataSource - Repository 應該是被動的

Repository 被動原則:
- Repository 只負責數據存取協調，不參與應用程式級事件流
- Repository 不應依賴事件系統，保持可測試性和可替換性
- 事件發布應由上層 Service/Manager/Coordinator 負責

實際場景範例:
```
✅ CORRECT: OnboardingCoordinator 發布 → TrainingPlanViewModel 訂閱 → Repository 被調用 (被動)
❌ WRONG: Repository 訂閱事件並自動清除緩存 (違反被動原則)
```

**5. Dependency Injection (依賴注入)**

**原則**: 使用 DependencyContainer 統一管理依賴

**注入層級**:
- Core Layer: HTTPClient, Logger (Singleton)
- Data Layer: DataSource, Mapper, RepositoryImpl (Singleton)
- Presentation Layer: ViewModel (Factory，每次創建新實例)

**ViewModel 使用方式**:
- View 透過 DI Container 解析 ViewModel
- ViewModel 依賴 Repository Protocol (不依賴具體實作)
- 所有依賴透過建構子注入

#### 數據流向

**標準數據流**:
```
User Interaction (View)
    ↓
ViewModel.method() (Presentation)
    ↓
Repository.getData() (Domain Protocol)
    ↓
RepositoryImpl.getData() (Data Implementation)
    ├─ Track A: LocalDataSource.load() → 立即返回緩存
    └─ Track B: RemoteDataSource.fetch() → 背景刷新
        ↓
    HTTPClient.request() (Core)
        ↓
    API Response → DTO
        ↓
    Mapper.toEntity(dto) → Entity
        ↓
    ViewModel.state = .loaded(entity)
        ↓
    View Re-render
```

**事件驅動流**:
```
Business Event (e.g., Onboarding完成)
    ↓
CacheEventBus.publish(.onboardingCompleted)
    ↓
ViewModel subscribes → clearCache() + forceRefresh()
    ↓
Repository.clearAllCache()
    ↓
Repository.forceRefreshFromAPI()
    ↓
ViewModel.state = .loaded(freshData)
    ↓
View Re-render
```

#### DTO vs Entity 區別

**DTO (Data Transfer Object)**:
- 定義在 Data Layer
- 與 API JSON 結構一一對應
- 使用 snake_case 命名 (與後端一致)
- 包含 `CodingKeys` 進行鍵名轉換
- 可包含後端的冗餘或技術性欄位

**Entity (Domain Model)**:
- 定義在 Domain Layer
- 純粹的業務模型
- 使用 camelCase 命名 (Swift 慣例)
- 包含業務邏輯方法
- 只包含業務需要的欄位

**Mapper (轉換器)**:
- 定義在 Data Layer
- 負責 DTO ↔ Entity 雙向轉換
- 處理數據類型轉換 (如 Unix timestamp → Date)
- 處理預設值填充

#### 錯誤處理策略

**Domain Layer 定義錯誤類型**:
- `DomainError` 枚舉定義所有業務級錯誤
- 提供用戶友好的錯誤訊息 (LocalizedError)
- 明確的錯誤分類: `.networkFailure`, `.serverFailure`, `.cacheFailure`, `.authFailure`, `.validationFailure`

**Error 轉換流程**:
```
API Error (URLError, HTTPError)
    ↓
Data Layer catches
    ↓
Convert to DomainError
    ↓
Throw to ViewModel
    ↓
ViewModel.state = .error(domainError)
    ↓
View displays ErrorView
```

#### Clean Architecture 核心優勢

1. **可測試性**: 每層可獨立測試，Mock Repository Protocol 即可測試 ViewModel
2. **可維護性**: 職責清晰，修改一層不影響其他層
3. **可擴展性**: 新增功能遵循相同模式，代碼結構一致
4. **技術無關性**: Domain Layer 不依賴具體技術實作 (SwiftUI, URLSession 等)
5. **業務邏輯集中**: 所有業務規則集中在 Domain Layer，易於理解和修改

#### 實作檢查清單

開發新功能時，確保遵循以下原則：

- [ ] ViewModel 只依賴 Repository Protocol，不依賴具體實作
- [ ] View 不包含業務邏輯，只負責渲染和用戶輸入
- [ ] Repository Protocol 定義在 Domain Layer
- [ ] RepositoryImpl 實作在 Data Layer，實現雙軌緩存
- [ ] DTO 定義在 Data Layer，Entity 定義在 Domain Layer
- [ ] 使用 Mapper 進行 DTO ↔ Entity 轉換
- [ ] 錯誤處理統一轉換為 DomainError
- [ ] ViewState enum 管理 UI 狀態
- [ ] 特殊事件使用 CacheEventBus 通知
- [ ] 所有依賴透過 DependencyContainer 注入

**詳細設計文檔**: 參見 `Docs/01-architecture/ARCH-002-Clean-Architecture-Design.md`

---

### 0. Verify Before Assuming (CRITICAL - 最優先原則)

**When debugging UI display issues, ALWAYS follow this systematic approach:**

1. **User feedback is the ground truth** - If user says "you changed the wrong view", stop immediately and verify
2. **Use tools to find all possibilities** - Never assume which view is responsible
3. **Evidence over intuition** - If logs don't appear, the view is NOT rendering

#### Debugging Display Issues - Required Steps:
```bash
# Step 1: Find ALL views that display the data
grep -r "Text.*targetVariable" Views/ --include="*.swift" -n

# Step 2: Check which views are actually used in the affected screen
# Read the parent view and trace the view hierarchy

# Step 3: Verify with evidence (logs, breakpoints)
# If no logs appear, that view is NOT the problem

# Step 4: Only AFTER verification, make changes
```

#### Anti-patterns that MUST be avoided:
```swift
// ❌ WRONG - Assuming without verification
"I think it's TrainingDetailsView, let me add logs there"
→ Result: Wasted time, wrong direction

// ✅ CORRECT - Verify first
grep -r "dayTarget" Views/Training/ -n  // Find all candidates
→ Check each view's usage context
→ Identify the actual culprit
→ Fix in 5 minutes
```

**Critical Rule**: When user questions your approach ("是不是改錯view"), treat it as a **red flag** - stop, verify all assumptions with grep/search, then proceed.

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