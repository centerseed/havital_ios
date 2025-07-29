# Havital iOS App

## Project Overview
This is the Havital iOS app, a fitness tracking application that integrates with various data sources including Garmin Connect.

## Development Setup
- iOS project built with Xcode
- Swift-based application
- Integration with Garmin SDK for workout tracking

## Project Structure
- `Havital/` - Main app directory
- `Havital/Managers/` - Core managers (GarminManager, UnifiedWorkoutManager, etc.)
- `Havital/Views/` - SwiftUI views organized by feature
- `Havital.xcodeproj/` - Xcode project file

## Key Features
- Garmin Connect integration
- Workout tracking and management
- User profile management
- Data synchronization
- Onboarding flow

## Recent Development
- Added Garmin workout support (v2)
- Enhanced data sync capabilities
- Updated UI for training intensity statistics
- Added push notification support
- Implemented comprehensive health data API integration with TaskManagement and CacheEventBus


### Best Practices

#### Task Management (Actor-based Thread-Safe Architecture)
- **ALWAYS use `TaskID` for task identification**: Use `TaskID("task_name")` instead of raw strings
- **Type-safe task execution**: `executeTask(id: TaskID("load_data")) { ... }`
- **Actor-based TaskRegistry**: Each class has `let taskRegistry = TaskRegistry()` for thread safety
- **Memory leak prevention**: Use `[weak self]` in all Task closures, especially in `deinit`
- **Proper cleanup**: Always call `cancelAllTasks()` in `deinit`
- **No Dictionary key mixing**: Never mix String and Date objects as Dictionary keys
- **Thread safety**: TaskRegistry Actor eliminates Dictionary race conditions
- **Error handling**: Implement proper error catching and logging
- Details: `Docs/ARCHITECTURE.md`

#### Dictionary Safety (CRITICAL - Prevents Crashes)
- **Never use Date objects as Dictionary keys**: Use `TimeInterval` instead
- **Always use type-safe keys**: Prefer `TaskID`, `String`, or primitive types
- **Group by TimeInterval**: `Dictionary(grouping:) { date.timeIntervalSince1970 }`
- **Convert back safely**: `Date(timeIntervalSince1970: timeInterval)`

#### Cache Management
- Implement proper TTL (Time To Live) logic
- Register all cache managers with CacheEventBus
- Use consistent cache key naming (TaskID recommended)
- Handle cache invalidation scenarios
- **Thread-safe operations**: All cache operations in taskQueue
- Details: `Docs/ARCHITECTURE.md`

#### Performance
- Avoid unnecessary UI updates
- Use `@MainActor` for UI property updates
- Implement proper loading states
- Cache frequently accessed data
- **Memory safety**: Always use `[weak self]` in async closures

## Unified Data Flow Architecture

### Core Pattern
```
HealthKit/Garmin → Backend API → Frontend (WorkoutV2/UserProfileData) → UI
```

**CRITICAL: Never convert API data back to HealthKit objects. Always API-first.**

### Implementation Standards

#### Manager Layer (`*Manager.swift`) - THREAD-SAFE
- **REQUIRED**: Implement `DataManageable` protocol with `@preconcurrency TaskManageable`
- **Task execution**: Use `executeDataLoadingTask(id: TaskID("load_operation"))` for API calls
- **Properties**: `var activeTasks: [TaskID: Task<Void, Never>] = [:]`
- **Memory safety**: Always `[weak self]` in closures
- **Cleanup**: `deinit { cancelAllTasks() }`
- **Dictionary grouping**: NEVER use Date as key, use `TimeInterval`

```swift
// ✅ CORRECT - Type-safe and thread-safe
class MyManager: ObservableObject, @preconcurrency TaskManageable {
    var activeTasks: [TaskID: Task<Void, Never>] = [:]
    
    func loadData() async {
        await executeDataLoadingTask(id: TaskID("load_data")) {
            // Group by TimeInterval, not Date
            let grouped = Dictionary(grouping: data) { item in
                item.date.timeIntervalSince1970  // ✅ SAFE
            }
            return processedData
        }
    }
    
    deinit { cancelAllTasks() }
}
```

#### ViewModel Layer (`*ViewModelV2.swift`) - MAIN-ACTOR SAFE
- **Extend**: `BaseDataViewModel<DataType, ManagerType>`
- **Concurrency**: Use `@MainActor` for UI updates
- **Error handling**: Use `executeWithErrorHandling` for user actions
- **State sync**: Proper binding with managers

#### Service Layer (`*Service.swift`) - API-FIRST
- Handle API communication with proper error handling
- Return API models (WorkoutV2, UserProfileData)
- **Never convert API data back to HealthKit objects**
- Implement retry logic and timeout handling

#### Cache Layer (`*CacheManager.swift`) - TYPE-SAFE
- **Use**: `BaseCacheManagerTemplate<DataType>`
- **Register**: with `CacheEventBus` for invalidation
- **Keys**: Use `TaskID` or safe string keys only
- **Thread safety**: All operations in manager's taskQueue

### Architecture Examples
- **Training Plans**: `TrainingPlanManager` + `TrainingPlanViewModelV2`
- **User Data**: `UserManager` + `UserProfileViewModelV2` 
- **HRV Data**: `HRVManager` + `HRVChartViewModelV2`
- **Workouts**: `UnifiedWorkoutManager` (reference implementation)

## Crash Prevention Checklist

### Before Deployment (MANDATORY)
- [ ] **No Date objects as Dictionary keys**: Search for `Dictionary.*Date` patterns
- [ ] **All managers use TaskID**: Search for `var activeTasks.*String:` (should be `TaskID:`)
- [ ] **Thread safety annotations**: All TaskManageable classes have `@preconcurrency`
- [ ] **Memory safety**: All async closures use `[weak self]`
- [ ] **Proper cleanup**: All managers implement `deinit { cancelAllTasks() }`

### Code Review Requirements
```swift
// ❌ FORBIDDEN - Will cause crashes
let grouped = Dictionary(grouping: data) { item in
    item.date  // Date object as key - CRASH RISK
}
var activeTasks: [String: Task<Void, Never>] = [:]  // String keys - UNSAFE

// ✅ REQUIRED - Safe patterns
let grouped = Dictionary(grouping: data) { item in
    item.date.timeIntervalSince1970  // TimeInterval as key - SAFE
}
var activeTasks: [TaskID: Task<Void, Never>] = [:]  // TaskID - TYPE SAFE
```

### Testing Commands
```bash
# Clean build to test changes (with thread safety checks)
cd "/Users/wubaizong/havital/apps/ios/Havital"
xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 16'

# Search for crash patterns before commit
grep -r "Dictionary.*Date" Havital/ --include="*.swift"
grep -r "var activeTasks.*String:" Havital/ --include="*.swift"
grep -r "executeTask.*\"" Havital/ --include="*.swift"  # Should use TaskID

# Runtime testing with crash detection
# Test all data loading scenarios extensively
# Monitor for NSTaggedPointerString errors in console
```

## Security & Stability Notes
- **All changes tested against crash logs** from TestFlight feedback
- **Zero tolerance for Dictionary key type mixing**
- **Mandatory code review** for any TaskManageable implementations
- **Performance tested** with concurrent operations

## Crash Validation Strategy

### ❌ What We Cannot Guarantee
- **修復的完整性**: 無法 100% 確認所有邊緣情況
- **真實設備表現**: 模擬器測試不等於真實設備
- **用戶行為模式**: 無法完全預測用戶操作序列

### ✅ What We Can Do
1. **運行壓力測試**: `Havital/Tests/TaskManageableStressTest.swift`
2. **監控崩潰率**: 通過 Firebase Crashlytics 追蹤改進
3. **階段性部署**: 先小範圍 TestFlight，再正式發布
4. **快速回滾計劃**: 如果崩潰率上升，立即回滾

### 📊 Success Metrics
- **崩潰率 < 0.1%**: 從 TestFlight 反饋評估
- **Dictionary 相關崩潰 = 0**: 特別監控 removeValue 崩潰
- **任務洩漏 = 0**: 通過內存監控確認
- **響應性能**: 任務執行延遲 < 100ms

### 🚨 回滾觸發條件
- 任何 Dictionary.removeValue 崩潰重現
- 崩潰率比之前版本上升 > 50%
- 內存洩漏導致性能問題
- 用戶報告數據載入失敗 > 5%
