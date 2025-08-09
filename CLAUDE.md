# Havital iOS App

## Project Overview
A fitness tracking application supporting Apple Health and Garmin Connect integration with comprehensive training plan management.

## Project Structure
- `Havital/Managers/` - Core business logic (UserManager, UnifiedWorkoutManager, etc.)
- `Havital/ViewModels/` - UI state management with TaskManageable protocol
- `Havital/Services/` - API communication layer
- `Havital/Views/` - SwiftUI views organized by feature
- `Havital/Storage/` - Local data persistence and caching

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

### 6. Debugging & Logging Strategy

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