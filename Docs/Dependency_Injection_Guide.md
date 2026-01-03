# Manager 依賴注入指南

## 為什麼需要依賴注入？

依賴注入讓我們可以：
1. ✅ 在測試中注入 Mock 對象
2. ✅ 避免 Xcode TEST_HOST 配置問題
3. ✅ 完全控制測試環境
4. ✅ 測試邊緣情況（網路錯誤、超時等）

## 實現步驟

### 1. 定義 Protocol

```swift
// Havital/Services/Protocols/TrainingPlanServiceProtocol.swift

protocol TrainingPlanServiceProtocol {
    func getTrainingOverview() async throws -> TrainingOverview
    func getWeeklyPlanById(_ planId: String) async throws -> WeeklyPlan
}

// 讓現有的 Service 遵循 Protocol
extension TrainingPlanService: TrainingPlanServiceProtocol {}
```

### 2. 添加依賴注入到 Manager

```swift
// Havital/Managers/TrainingPlanManager.swift

class TrainingPlanManager: ObservableObject, @preconcurrency TaskManageable {
    let taskRegistry = TaskRegistry()

    // 依賴注入
    private let service: TrainingPlanServiceProtocol
    private let storage: TrainingPlanStorageProtocol

    // 生產環境使用真實依賴
    init(
        service: TrainingPlanServiceProtocol = TrainingPlanService.shared,
        storage: TrainingPlanStorageProtocol = TrainingPlanStorage.shared
    ) {
        self.service = service
        self.storage = storage
    }

    // 測試專用初始化器
    #if DEBUG
    init(
        service: TrainingPlanServiceProtocol,
        storage: TrainingPlanStorageProtocol
    ) {
        self.service = service
        self.storage = storage
    }
    #endif

    func loadTrainingOverview() async {
        await executeTask(id: TaskID("load_overview")) { [weak self] in
            guard let self = self else { return }

            // 軌道 A: 緩存
            if let cached = storage.getCachedOverview() {
                await MainActor.run {
                    self.trainingOverview = cached
                    self.isLoadingOverview = false
                }

                // 軌道 B: 背景刷新
                Task.detached { [weak self] in
                    await self?.refreshOverviewInBackground()
                }
                return
            }

            // 沒有緩存，從 API 載入
            do {
                let overview = try await service.getTrainingOverview()
                await MainActor.run {
                    self.trainingOverview = overview
                    self.isLoadingOverview = false
                }
                storage.saveOverview(overview)
            } catch {
                // 處理錯誤
                await handleError(error)
            }
        }
    }

    private func refreshOverviewInBackground() async {
        do {
            let fresh = try await service.getTrainingOverview()
            await MainActor.run { self.trainingOverview = fresh }
            storage.saveOverview(fresh)
        } catch {
            // 背景刷新失敗不影響 UI
            Logger.debug("背景刷新失敗: \(error.localizedDescription)")
        }
    }
}
```

### 3. 定義 Storage Protocol

```swift
// Havital/Storage/Protocols/TrainingPlanStorageProtocol.swift

protocol TrainingPlanStorageProtocol {
    func getCachedOverview() -> TrainingOverview?
    func saveOverview(_ overview: TrainingOverview)
    func getCachedWeeklyPlan(week: Int) -> WeeklyPlan?
    func saveWeeklyPlan(_ plan: WeeklyPlan)
    func clearCache()
}

// 讓現有的 Storage 遵循 Protocol
extension TrainingPlanStorage: TrainingPlanStorageProtocol {}
```

### 4. 在測試中使用

```swift
// HavitalTests/Managers/TrainingPlanManagerTests.swift

@MainActor
final class TrainingPlanManagerTests: XCTestCase {
    var sut: TrainingPlanManager!
    var mockService: MockTrainingPlanService!
    var mockStorage: MockTrainingPlanStorage!

    override func setUp() async throws {
        mockService = MockTrainingPlanService()
        mockStorage = MockTrainingPlanStorage()

        // 注入 mock 依賴
        sut = TrainingPlanManager(
            service: mockService,
            storage: mockStorage
        )
    }

    func test_withCache_shouldDisplayImmediately() async {
        // Given: 緩存有數據
        mockStorage.cachedOverview = TrainingOverview.mockData()

        // When: 載入
        await sut.loadTrainingOverview()

        // Then: 立即顯示
        XCTAssertNotNil(sut.trainingOverview)
    }
}
```

## 快速實現 Checklist

對於每個 Manager，執行以下步驟：

### TrainingPlanManager
- [ ] 創建 `TrainingPlanServiceProtocol`
- [ ] 創建 `TrainingPlanStorageProtocol`
- [ ] 在 `TrainingPlanManager` 添加依賴注入
- [ ] 更新所有使用 `TrainingPlanService.shared` 的地方
- [ ] 運行測試驗證

### UnifiedWorkoutManager
- [ ] 創建 `WorkoutServiceProtocol`
- [ ] 創建 `WorkoutStorageProtocol`
- [ ] 添加依賴注入
- [ ] 創建測試

### TargetManager
- [ ] 創建 `TargetServiceProtocol`
- [ ] 創建 `TargetStorageProtocol`
- [ ] 添加依賴注入
- [ ] 創建測試

## 測試模板

```swift
// Mock Service 模板
class MockTrainingPlanService: TrainingPlanServiceProtocol {
    var mockOverview: TrainingOverview?
    var shouldFail = false
    var callCount = 0

    func getTrainingOverview() async throws -> TrainingOverview {
        callCount += 1

        if shouldFail {
            throw NSError(domain: "Test", code: -1)
        }

        guard let overview = mockOverview else {
            throw NSError(domain: "Test", code: -2)
        }

        return overview
    }
}

// Mock Storage 模板
class MockTrainingPlanStorage: TrainingPlanStorageProtocol {
    var cachedOverview: TrainingOverview?
    var didSave = false

    func getCachedOverview() -> TrainingOverview? {
        return cachedOverview
    }

    func saveOverview(_ overview: TrainingOverview) {
        cachedOverview = overview
        didSave = true
    }
}
```

## 驗證測試

運行測試驗證依賴注入是否正常工作：

```bash
# 運行特定測試
xcodebuild test \
  -project Havital.xcodeproj \
  -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:HavitalTests/TrainingPlanManagerTests
```

## 優點總結

### 傳統方式（無依賴注入）
- ❌ 依賴 TEST_HOST 配置
- ❌ 無法控制測試環境
- ❌ 難以測試錯誤情況
- ❌ 測試緩慢（真實 API 調用）

### 依賴注入方式
- ✅ 不依賴 TEST_HOST
- ✅ 完全控制測試環境
- ✅ 輕鬆測試各種情況
- ✅ 測試快速（純內存操作）
- ✅ 100% 可靠（不受網路影響）

## 下一步

1. 為 TrainingPlanManager 添加依賴注入
2. 運行測試驗證
3. 逐步遷移其他 Manager
4. 建立完整的測試覆蓋率

參考實現: `HavitalTests/Managers/TrainingPlanManagerTests.swift`
