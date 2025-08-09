# Havital iOS App - 統一架構指南

## 概覽

本文件說明 Havital iOS App 的統一數據流架構，基於 `UnifiedWorkoutManager` 的最佳實踐模式，提供一致性、可維護性和可擴展性的數據管理解決方案。

## 核心原則

### 1. 統一架構模式
- **Service Layer**: API 通信和錯誤處理
- **Manager Layer**: 業務邏輯，實現 `DataManageable` 協議
- **Cache Layer**: 使用 `BaseCacheManagerTemplate` 的統一快取管理
- **ViewModel Layer**: SwiftUI 整合，繼承 `BaseDataViewModel`
- **Notification System**: 跨組件通信使用標準化通知

### 2. 關注點分離
- **Manager**: 處理業務邏輯、任務管理、快取策略
- **ViewModel**: 處理 UI 狀態、用戶互動、顯示邏輯
- **Service**: 處理 API 通信、網路錯誤、數據轉換
- **Cache**: 處理數據持久化、TTL 管理、失效策略

### 3. 一致性標準
- 所有 Manager 實現 `DataManageable` 協議
- 所有 ViewModel 繼承 `BaseDataViewModel`
- 所有 Cache 使用 `BaseCacheManagerTemplate`
- 所有通知使用標準化命名和 UserInfo 鍵

## 核心協議和基礎類

### DataManageable 協議

```swift
protocol DataManageable: TaskManageable, Cacheable {
    associatedtype DataType: Codable
    associatedtype ServiceType
    
    // 核心數據屬性
    var isLoading: Bool { get set }
    var lastSyncTime: Date? { get set }
    var syncError: String? { get set }
    
    // 依賴服務
    var service: ServiceType { get }
    
    // 標準化方法
    func initialize() async
    func loadData() async
    func refreshData() async -> Bool
    func clearAllData() async
}
```

### BaseDataViewModel

```swift
@MainActor
class BaseDataViewModel<DataType: Codable, ManagerType: DataManageable>: ObservableObject {
    @Published var isLoading = false
    @Published var data: [DataType] = []
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    let manager: ManagerType
    
    func initialize() async
    func loadData() async
    func refreshData() async
    func clearAllData() async
}
```

### BaseCacheManagerTemplate

```swift
class BaseCacheManagerTemplate<DataType: Codable>: BaseCacheManager {
    let cacheIdentifier: String
    let cacheKey: String
    let defaultTTL: TimeInterval
    
    func saveToCache(_ data: DataType)
    func loadFromCache() -> DataType?
    func clearCache()
    func getCacheSize() -> Int
    func isExpired() -> Bool
}
```

## 實現模式

### 1. Manager 實現模式

```swift
class ExampleManager: ObservableObject, DataManageable {
    // Type Definitions
    typealias DataType = ExampleDataModel
    typealias ServiceType = ExampleService
    
    // Published Properties
    @Published var isLoading = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    // Specific Properties
    @Published var exampleData: [ExampleDataModel] = []
    
    // Dependencies
    let service: ExampleService
    private let cacheManager: ExampleCacheManager
    
    // TaskManageable Properties
    var activeTasks: [String: Task<Void, Never>] = [:]
    
    // Cacheable Properties
    var cacheIdentifier: String { "ExampleManager" }
    
    // Implementation...
}
```

### 2. ViewModel 實現模式

```swift
@MainActor
class ExampleViewModelV2: BaseDataViewModel<ExampleDataModel, ExampleManager> {
    // Specific Properties
    @Published var selectedItem: ExampleDataModel?
    
    override init(manager: ExampleManager = ExampleManager.shared) {
        super.init(manager: manager)
        bindManagerProperties()
    }
    
    // Custom Methods
    func selectItem(_ item: ExampleDataModel) {
        selectedItem = item
    }
    
    private func syncManagerState() {
        // 同步 manager 狀態到 ViewModel
    }
}
```

### 3. Cache Manager 實現模式

```swift
private class ExampleCacheManager: BaseCacheManagerTemplate<ExampleCacheData> {
    init() {
        super.init(identifier: "example_cache", defaultTTL: 1800) // 30 minutes
    }
    
    // Specialized Methods
    func saveSpecificData(_ data: SpecificData) {
        var cacheData = loadFromCache() ?? ExampleCacheData()
        cacheData.specificData = data
        saveToCache(cacheData)
    }
    
    func loadSpecificData() -> SpecificData? {
        return loadFromCache()?.specificData
    }
}

private struct ExampleCacheData: Codable {
    var specificData: SpecificData?
    // Other cached data...
}
```

## 通知系統

### 標準化通知名稱

```swift
extension Notification.Name {
    // Data Update Notifications
    static let exampleDataDidUpdate = Notification.Name("exampleDataDidUpdate")
    static let trainingPlanDidUpdate = Notification.Name("trainingPlanDidUpdate")
    static let hrvDataDidUpdate = Notification.Name("hrvDataDidUpdate")
    static let vdotDataDidUpdate = Notification.Name("vdotDataDidUpdate")
    static let userDataDidUpdate = Notification.Name("userDataDidUpdate")
    
    // Cache Events
    static let cacheDidInvalidate = Notification.Name("cacheDidInvalidate")
    static let globalDataRefresh = Notification.Name("globalDataRefresh")
}
```

### UserInfo 鍵

```swift
extension String {
    static let dataTypeKey = "dataType"
    static let cacheIdentifierKey = "cacheIdentifier"
    static let errorKey = "error"
    static let sourceKey = "source"
}
```

## 快取策略

### TTL 配置建議

- **用戶數據**: 1 小時 (3600 秒)
- **運動記錄**: 5 分鐘 (300 秒)
- **訓練計劃**: 30 分鐘 (1800 秒)
- **HRV 數據**: 30 分鐘 (1800 秒)
- **VDOT 數據**: 30 分鐘 (1800 秒)
- **健康數據**: 30 分鐘 (1800 秒)

### 快取失效策略

```swift
// 數據變更時自動失效相關快取
CacheEventBus.shared.invalidateCache(for: .dataChanged(.workouts))

// 用戶登出時清除所有快取
CacheEventBus.shared.invalidateCache(for: .userLogout)

// 手動清除快取
CacheEventBus.shared.invalidateCache(for: .manualClear)
```

## 錯誤處理

### 標準化錯誤處理

```swift
// Manager 層錯誤處理
await executeDataLoadingTask(id: "load_data") {
    do {
        let data = try await service.fetchData()
        // 處理成功情況
        return data
    } catch {
        // 錯誤會自動設置到 syncError
        Logger.firebase(
            "數據載入失敗: \(error.localizedDescription)",
            level: .error,
            labels: ["module": "ExampleManager", "action": "load_data"]
        )
        throw error
    }
}

// ViewModel 層錯誤處理
await executeWithErrorHandling {
    try await someOperation()
}
```

### 網路錯誤處理

```swift
func handleAPIError(_ error: Error, context: String) -> Error {
    Logger.firebase(
        "API 請求失敗: \(context)",
        level: .error,
        jsonPayload: [
            "context": context,
            "error": error.localizedDescription,
            "error_type": String(describing: type(of: error))
        ]
    )
    return error
}
```

## 最佳實踐

### 1. 任務管理

```swift
// 防止重複 API 調用
await executeTask(id: "unique_task_id") {
    // 任務邏輯
}

// 在 deinit 中取消所有任務
deinit {
    cancelAllTasks()
}
```

### 2. 主線程更新

```swift
// 確保 UI 更新在主線程
await MainActor.run {
    self.isLoading = false
    self.data = newData
}
```

### 3. 背景刷新

```swift
// 不阻塞 UI 的背景更新
func backgroundRefresh() async {
    _ = await executeDataLoadingTask(id: "background_refresh", showLoading: false) {
        return await refreshData()
    }
}
```

### 4. 通知觀察者管理

```swift
// 使用陣列管理通知觀察者
private var notificationObservers: [NSObjectProtocol] = []

// 在 deinit 中移除觀察者
deinit {
    notificationObservers.forEach { observer in
        NotificationCenter.default.removeObserver(observer)
    }
}
```

### 5. 數據同步

```swift
// 使用通知進行跨組件數據同步
NotificationCenter.default.post(name: .exampleDataDidUpdate, object: nil)

// 監聽數據更新
NotificationCenter.default.addObserver(
    forName: .exampleDataDidUpdate,
    object: nil,
    queue: .main
) { [weak self] _ in
    self?.syncManagerState()
}
```

## 測試策略

### 1. 單元測試

```swift
@MainActor
class ExampleManagerTests: XCTestCase {
    var manager: ExampleManager!
    var mockService: MockExampleService!
    
    override func setUp() async throws {
        mockService = MockExampleService()
        manager = ExampleManager(service: mockService)
    }
    
    func testLoadData() async throws {
        // 設置 mock 數據
        mockService.mockData = [ExampleDataModel()]
        
        // 執行測試
        await manager.loadData()
        
        // 驗證結果
        XCTAssertFalse(manager.isLoading)
        XCTAssertEqual(manager.exampleData.count, 1)
    }
}
```

### 2. 整合測試

```swift
func testManagerViewModelIntegration() async throws {
    let manager = ExampleManager.shared
    let viewModel = ExampleViewModelV2(manager: manager)
    
    await viewModel.initialize()
    
    XCTAssertEqual(viewModel.data.count, manager.exampleData.count)
}
```

## 遷移指南

### 從舊架構遷移

1. **創建新的 Manager**: 實現 `DataManageable` 協議
2. **重構 ViewModel**: 繼承 `BaseDataViewModel`
3. **更新 Cache**: 使用 `BaseCacheManagerTemplate`
4. **添加通知**: 使用標準化通知系統
5. **更新 UI**: 逐步替換 UI 使用新的 ViewModel

### 向後兼容性

```swift
// 在新 ViewModel 中提供舊方法的兼容性
extension ExampleViewModelV2 {
    // Legacy method names
    func fetchData() async {
        await loadData()
    }
    
    // Legacy property compatibility
    var error: Error? {
        get {
            if let syncError = syncError {
                return NSError(domain: "ExampleError", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: syncError
                ])
            }
            return nil
        }
        set {
            syncError = newValue?.localizedDescription
        }
    }
}
```

## 性能優化

### 1. 快取最佳化

- 使用適當的 TTL 避免過頻繁的 API 調用
- 實現條件式快取更新（只有數據改變時才更新）
- 使用 `forceRefresh` 進行強制更新

### 2. 任務管理最佳化

- 避免重複的任務執行
- 使用適當的任務 ID 防止衝突
- 在組件銷毀時取消未完成的任務

### 3. 記憶體管理

- 使用 weak references 避免循環引用
- 適時清理快取數據
- 監控快取大小並實施清理策略

## 總結

統一架構指南提供了：

- ✅ **一致性**: 所有功能使用相同的架構模式
- ✅ **可維護性**: 清晰的關注點分離和標準化實現
- ✅ **可擴展性**: 易於添加新功能和修改現有功能
- ✅ **效能最佳化**: 統一的快取策略和任務管理
- ✅ **錯誤處理**: 標準化的錯誤處理和日誌記錄
- ✅ **測試友好**: 易於進行單元測試和整合測試

遵循此指南將確保代碼庫的長期可維護性和一致性。