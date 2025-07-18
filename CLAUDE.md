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

## Major Architecture Improvements (2025-07-18)

### Overview
Implemented a comprehensive architecture overhaul focusing on task management, cache consistency, and performance optimization. The changes provide better maintainability, prevent duplicate API calls, and ensure smooth user experience.

### Key Improvements

#### 1. Task Management System
**Location**: `Havital/Protocols/TaskManageable.swift`

Implemented a protocol-based task management system to prevent duplicate API calls and provide proper cancellation mechanisms:

```swift
protocol TaskManageable: AnyObject {
    var activeTasks: [String: Task<Void, Never>] { get set }
    
    func executeTask<T>(id: String, operation: @escaping () async throws -> T) async -> T?
    func cancelTask(id: String)
    func cancelAllTasks()
}
```

**Key Features**:
- Automatic cancellation of duplicate tasks with same ID
- Proper Task object management
- Built-in error handling and logging
- Thread-safe operations

**Fixed Issues**:
- ✅ Eliminated duplicate API requests
- ✅ Proper task cancellation now works correctly
- ✅ Prevents race conditions in concurrent operations

#### 2. Cache Event Bus System
**Location**: `Havital/Utils/CacheEventBus.swift`

Implemented an event-driven cache management system for coordinated cache operations:

```swift
class CacheEventBus {
    static let shared = CacheEventBus()
    
    func register(_ cacheable: Cacheable)
    func invalidateCache(for reason: CacheInvalidationReason)
    func clearAllCaches()
    func getCacheStatus() -> [CacheStatus]
}
```

**Key Features**:
- Centralized cache coordination
- Event-driven invalidation
- Unified cache status monitoring
- Automatic cache registration

#### 3. Cacheable Protocol
**Location**: `Havital/Protocols/Cacheable.swift`

Standardized cache management across all cache managers:

```swift
protocol Cacheable: AnyObject {
    var cacheIdentifier: String { get }
    func clearCache()
    func getCacheSize() -> Int
    func isExpired() -> Bool
}
```

**Implemented in**:
- `WorkoutV2CacheManager`
- `TrainingPlanStorage`
- `TargetStorage`
- `WeeklySummaryStorage`

#### 4. Updated Classes with TaskManageable

**Updated Files**:
- `UnifiedWorkoutManager.swift` - Main workout data coordination
- `TrainingPlanViewModel.swift` - Training plan UI logic
- `WorkoutDetailViewModelV2.swift` - Workout detail display
- `AuthenticationService.swift` - User authentication

**Key Change**: All classes now use `[String: Task<Void, Never>]` instead of `Set<String>` for proper task management.

#### 5. UI Performance Improvements
**Location**: `Havital/Views/Training/TrainingPlanView.swift`

Fixed screen flashing issues when switching between tabs:

- ✅ Optimized `onAppear` behavior to avoid unnecessary reloads
- ✅ Removed forced view recreation with `.id()` modifier
- ✅ Prevented unnecessary loading states
- ✅ Improved data persistence during tab switches

#### 6. Log Optimization
**Location**: `Havital/Utils/TrainingDateUtils.swift`

Removed redundant DEBUG logs that were causing log noise:
- ✅ Eliminated repetitive date calculation logs
- ✅ Cleaner console output for debugging

### How to Add New API Calls with TaskManager

When adding new API calls, follow this pattern:

#### Step 1: Implement TaskManageable Protocol
```swift
class YourViewModel: ObservableObject, TaskManageable {
    var activeTasks: [String: Task<Void, Never>] = [:]
    
    // Your existing code...
}
```

#### Step 2: Wrap API Calls with Task Management
```swift
func loadData() async {
    await executeTask(id: "load_data") {
        await self.performLoadData()
    }
}

private func performLoadData() async {
    do {
        let data = try await yourAPIService.fetchData()
        await MainActor.run {
            self.data = data
        }
    } catch {
        Logger.error("Failed to load data: \(error)")
    }
}
```

#### Step 3: Use Unique Task IDs
- Use descriptive IDs: `"load_workouts"`, `"refresh_training_plan"`, `"fetch_user_profile"`
- Ensure IDs are unique within the same class
- Related operations can cancel each other by using the same ID

### How to Add New Cache Managers

#### Step 1: Implement Cacheable Protocol
```swift
class YourCacheManager: Cacheable {
    static let shared = YourCacheManager()
    
    var cacheIdentifier: String { "YourCacheManager" }
    
    func clearCache() {
        // Clear your cache data
    }
    
    func getCacheSize() -> Int {
        // Return cache size
    }
    
    func isExpired() -> Bool {
        // Check if cache has expired
    }
}
```

#### Step 2: Register with CacheEventBus
```swift
// In AppViewModel.swift or appropriate initialization location
CacheEventBus.shared.register(YourCacheManager.shared)
```

#### Step 2.5: Update Cache Relationships (If needed)
If your new cache is related to existing data types, update the `getRelatedCacheIdentifiers` method in `CacheEventBus.swift`:

```swift
private func getRelatedCacheIdentifiers(for dataType: DataType) -> Set<String> {
    switch dataType {
    case .workouts:
        return ["workouts_v2"]
    case .trainingPlan:
        return ["training_plan", "weekly_summary"] // 訓練計劃影響週總結
    case .weeklySummary:
        return ["weekly_summary"]
    case .targets:
        return ["targets", "training_plan"] // 目標影響訓練計劃
    case .user:
        return Set(cacheables.map { $0.cacheIdentifier }) // 用戶變更影響所有
    // Add new case if needed:
    // case .yourNewDataType:
    //     return ["your_cache_identifier", "related_cache_identifier"]
    }
}
```

**When to update this method**:
- If your new cache stores data that should be invalidated when other data changes
- If other caches should be invalidated when your new data changes
- If you need to add a new `DataType` enum case

**Current DataType enum** (in `Cacheable.swift`):
```swift
enum DataType {
    case workouts
    case trainingPlan
    case weeklySummary
    case targets
    case user
}
```

**Example scenarios**:

1. **Adding cache to existing data type**: If you add a "UserPreferences" cache that should be cleared when user data changes:
   - Add `"user_preferences"` to the `.user` case: `return Set(cacheables.map { $0.cacheIdentifier })`

2. **Adding new data type**: If you add a "Nutrition" feature with its own cache:
   - Add `.nutrition` to the `DataType` enum
   - Add the case to `getRelatedCacheIdentifiers`: `case .nutrition: return ["nutrition_cache"]`
   - If nutrition data affects training plans, update the `.trainingPlan` case accordingly

#### Step 3: Implement Cache Logic
```swift
func getCachedData<T>(key: String, maxAge: TimeInterval) -> T? {
    // Check cache validity
    // Return cached data if valid
    // Return nil if expired or not found
}

func cacheData<T>(_ data: T, key: String) {
    // Store data with timestamp
    // Implement TTL (Time To Live) logic
}
```

### Best Practices

#### Task Management
- Always use `executeTask` for API calls
- Use descriptive task IDs
- Handle cancellation gracefully
- Don't forget to call `cancelAllTasks()` in `deinit`

#### Cache Management
- Implement proper TTL (Time To Live) logic
- Register all cache managers with CacheEventBus
- Use consistent cache key naming
- Handle cache invalidation scenarios

#### Performance
- Avoid unnecessary UI updates
- Use `@MainActor` for UI property updates
- Implement proper loading states
- Cache frequently accessed data

### Testing Commands
```bash
# Clean build to test changes
cd "/Users/wubaizong/havital/apps/ios/Havital"
xcodebuild clean build -project Havital.xcodeproj -scheme Havital

# Check for Swift concurrency issues
xcodebuild build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 15' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

This architecture provides a solid foundation for future development with proper error handling, performance optimization, and maintainable code structure.