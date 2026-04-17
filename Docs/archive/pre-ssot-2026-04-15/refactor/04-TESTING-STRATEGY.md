# TrainingPlan 模組測試策略

## 測試金字塔

```
┌────────────────────────────────────────┐
│  集成測試 (10%)                         │
│  測試完整用戶流程                       │
│  - TrainingPlanViewModelIntegration    │
└────────────────────────────────────────┘
              ↑
┌────────────────────────────────────────┐
│  單元測試 (90%)                         │
│  測試獨立組件邏輯                       │
│  - Repository 測試                     │
│  - DataSource 測試                     │
│  - ViewModel 測試（隔離）               │
└────────────────────────────────────────┘
              ↑
┌────────────────────────────────────────┐
│  Mock/Stub 層                          │
│  提供測試替身                           │
└────────────────────────────────────────┘
```

## 測試目錄結構

```
HavitalTests/
├── TrainingPlan/
│   ├── Mocks/
│   │   ├── MockHTTPClient.swift
│   │   ├── MockUserDefaults.swift
│   │   ├── MockTrainingPlanRepository.swift
│   │   └── TestFixtures.swift
│   │
│   ├── Unit/
│   │   ├── Repository/
│   │   │   ├── TrainingPlanRepositoryImplTests.swift
│   │   │   └── CacheStrategyTests.swift
│   │   │
│   │   ├── DataSource/
│   │   │   ├── TrainingPlanRemoteDataSourceTests.swift
│   │   │   └── TrainingPlanLocalDataSourceTests.swift
│   │   │
│   │   └── ViewModel/
│   │       └── TrainingPlanViewModelTests.swift
│   │
│   └── Integration/
│       └── TrainingPlanViewModelIntegrationTests.swift
│
└── Helpers/
    ├── XCTestCase+Async.swift
    └── TestLogger.swift
```

## 測試腳本使用方式

### 基本用法

```bash
# 運行所有測試
./Scripts/test_training_plan.sh

# 運行所有測試（清理構建）
./Scripts/test_training_plan.sh all --clean

# 只運行單元測試
./Scripts/test_training_plan.sh unit

# 只運行集成測試
./Scripts/test_training_plan.sh integration

# 只運行 Repository 測試
./Scripts/test_training_plan.sh repository

# 只運行 DataSource 測試
./Scripts/test_training_plan.sh datasource

# 只運行 ViewModel 測試
./Scripts/test_training_plan.sh viewmodel
```

### 快速測試工作流

```bash
# 開發時：快速運行相關測試
./Scripts/test_training_plan.sh repository

# 提交前：運行所有測試
./Scripts/test_training_plan.sh all --clean

# CI/CD：運行所有測試並生成報告
./Scripts/test_training_plan.sh all --clean
```

## 測試實現計劃

### 階段 1: Mock 層實現（1-2 小時）

#### 1.1 MockHTTPClient
**目的**: 模擬 HTTP 請求，避免真實網路調用

```swift
// HavitalTests/TrainingPlan/Mocks/MockHTTPClient.swift
final class MockHTTPClient: HTTPClient {
    // 配置預期的響應
    var mockResponses: [String: Result<Data, Error>] = [:]
    var requestHistory: [(path: String, method: HTTPMethod, body: Data?)] = []

    func request(path: String, method: HTTPMethod, body: Data?) async throws -> Data {
        // 記錄請求歷史
        requestHistory.append((path, method, body))

        // 返回預設響應
        let key = "\(method.rawValue):\(path)"
        guard let response = mockResponses[key] else {
            throw HTTPError.notFound
        }

        switch response {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
}
```

**測試覆蓋**:
- ✅ 成功響應
- ✅ 錯誤響應（404, 500 等）
- ✅ 網路超時
- ✅ 請求歷史記錄

#### 1.2 MockUserDefaults
**目的**: 隔離測試，避免影響真實的 UserDefaults

```swift
// HavitalTests/TrainingPlan/Mocks/MockUserDefaults.swift
final class MockUserDefaults: UserDefaults {
    private var storage: [String: Any] = [:]

    override func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    override func data(forKey defaultName: String) -> Data? {
        return storage[defaultName] as? Data
    }

    override func object(forKey defaultName: String) -> Any? {
        return storage[defaultName]
    }

    override func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }

    func clear() {
        storage.removeAll()
    }
}
```

#### 1.3 TestFixtures
**目的**: 提供測試數據

```swift
// HavitalTests/TrainingPlan/Mocks/TestFixtures.swift
enum TrainingPlanFixtures {
    static let weeklyPlan1 = WeeklyPlan(
        id: "plan_123_1",
        weekOfPlan: 1,
        // ... 完整測試數據
    )

    static let trainingOverview = TrainingPlanOverview(
        id: "overview_123",
        mainRaceId: "race_456",
        // ... 完整測試數據
    )

    static let planStatus = PlanStatusResponse(
        hasPlan: true,
        currentWeek: 1,
        // ... 完整測試數據
    )
}
```

### 階段 2: DataSource 單元測試（2-3 小時）

#### 2.1 TrainingPlanLocalDataSourceTests

```swift
// HavitalTests/TrainingPlan/Unit/DataSource/TrainingPlanLocalDataSourceTests.swift
final class TrainingPlanLocalDataSourceTests: XCTestCase {
    var sut: TrainingPlanLocalDataSource!
    var mockDefaults: MockUserDefaults!

    override func setUp() {
        super.setUp()
        mockDefaults = MockUserDefaults()
        sut = TrainingPlanLocalDataSource(defaults: mockDefaults)
    }

    override func tearDown() {
        mockDefaults.clear()
        sut = nil
        mockDefaults = nil
        super.tearDown()
    }

    // MARK: - Weekly Plan Tests

    func testSaveAndGetWeeklyPlan() {
        // Given
        let plan = TrainingPlanFixtures.weeklyPlan1
        let planId = "plan_123_1"

        // When
        sut.saveWeeklyPlan(plan, planId: planId)
        let retrieved = sut.getWeeklyPlan(planId: planId)

        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, plan.id)
        XCTAssertEqual(retrieved?.weekOfPlan, plan.weekOfPlan)
    }

    func testWeeklyPlanExpiration() {
        // Given
        let plan = TrainingPlanFixtures.weeklyPlan1
        let planId = "plan_123_1"
        sut.saveWeeklyPlan(plan, planId: planId)

        // When - 立即檢查
        let isExpiredImmediately = sut.isWeeklyPlanExpired(planId: planId)

        // Then - 應該未過期
        XCTAssertFalse(isExpiredImmediately)
    }

    func testRemoveWeeklyPlan() {
        // Given
        let plan = TrainingPlanFixtures.weeklyPlan1
        let planId = "plan_123_1"
        sut.saveWeeklyPlan(plan, planId: planId)

        // When
        sut.removeWeeklyPlan(planId: planId)
        let retrieved = sut.getWeeklyPlan(planId: planId)

        // Then
        XCTAssertNil(retrieved)
    }

    // MARK: - Overview Tests

    func testSaveAndGetOverview() {
        // Given
        let overview = TrainingPlanFixtures.trainingOverview

        // When
        sut.saveOverview(overview)
        let retrieved = sut.getOverview()

        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, overview.id)
    }

    // MARK: - Plan Status Tests

    func testSaveAndGetPlanStatus() {
        // Given
        let status = TrainingPlanFixtures.planStatus

        // When
        sut.savePlanStatus(status)
        let retrieved = sut.getPlanStatus()

        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.hasPlan, status.hasPlan)
    }

    // MARK: - Cache Management Tests

    func testClearAll() {
        // Given
        sut.saveOverview(TrainingPlanFixtures.trainingOverview)
        sut.savePlanStatus(TrainingPlanFixtures.planStatus)
        sut.saveWeeklyPlan(TrainingPlanFixtures.weeklyPlan1, planId: "plan_123_1")

        // When
        sut.clearAll()

        // Then
        XCTAssertNil(sut.getOverview())
        XCTAssertNil(sut.getPlanStatus())
        XCTAssertNil(sut.getWeeklyPlan(planId: "plan_123_1"))
    }
}
```

**測試覆蓋**:
- ✅ 保存/讀取週計劃
- ✅ 保存/讀取訓練概覽
- ✅ 保存/讀取計劃狀態
- ✅ TTL 過期檢查
- ✅ 清除緩存
- ✅ 獲取緩存大小

#### 2.2 TrainingPlanRemoteDataSourceTests

```swift
// HavitalTests/TrainingPlan/Unit/DataSource/TrainingPlanRemoteDataSourceTests.swift
final class TrainingPlanRemoteDataSourceTests: XCTestCase {
    var sut: TrainingPlanRemoteDataSource!
    var mockHTTPClient: MockHTTPClient!
    var mockParser: MockAPIParser!

    override func setUp() async throws {
        try await super.setUp()
        mockHTTPClient = MockHTTPClient()
        mockParser = MockAPIParser()
        sut = TrainingPlanRemoteDataSource(
            httpClient: mockHTTPClient,
            parser: mockParser
        )
    }

    // MARK: - Weekly Plan Tests

    func testGetWeeklyPlan_Success() async throws {
        // Given
        let planId = "plan_123_1"
        let expectedPlan = TrainingPlanFixtures.weeklyPlan1
        let mockData = try JSONEncoder().encode(expectedPlan)

        mockHTTPClient.mockResponses[
            "GET:/plan/race_run/weekly/\(planId)"
        ] = .success(mockData)

        // When
        let result = try await sut.getWeeklyPlan(planId: planId)

        // Then
        XCTAssertEqual(result.id, expectedPlan.id)
        XCTAssertEqual(mockHTTPClient.requestHistory.count, 1)
        XCTAssertEqual(mockHTTPClient.requestHistory[0].path, "/plan/race_run/weekly/\(planId)")
    }

    func testGetWeeklyPlan_NotFound() async throws {
        // Given
        let planId = "nonexistent"
        mockHTTPClient.mockResponses[
            "GET:/plan/race_run/weekly/\(planId)"
        ] = .failure(HTTPError.notFound)

        // When/Then
        do {
            _ = try await sut.getWeeklyPlan(planId: planId)
            XCTFail("應該拋出 notFound 錯誤")
        } catch let error as HTTPError {
            if case .notFound = error {
                // 預期的錯誤
            } else {
                XCTFail("錯誤類型不正確: \(error)")
            }
        }
    }

    func testCreateWeeklyPlan_Success() async throws {
        // Given
        let week = 2
        let expectedPlan = TrainingPlanFixtures.weeklyPlan1
        let mockData = try JSONEncoder().encode(expectedPlan)

        mockHTTPClient.mockResponses[
            "POST:/plan/race_run/weekly/v2"
        ] = .success(mockData)

        // When
        let result = try await sut.createWeeklyPlan(
            week: week,
            startFromStage: nil,
            isBeginner: false
        )

        // Then
        XCTAssertEqual(result.id, expectedPlan.id)
        XCTAssertEqual(mockHTTPClient.requestHistory.count, 1)
        XCTAssertEqual(mockHTTPClient.requestHistory[0].method, .POST)
    }
}
```

**測試覆蓋**:
- ✅ GET 週計劃（成功/失敗）
- ✅ POST 創建週計劃
- ✅ PUT 修改週計劃
- ✅ GET 訓練概覽
- ✅ GET 計劃狀態
- ✅ 錯誤處理（404, 500, 超時）

### 階段 3: Repository 單元測試（3-4 小時）

#### 3.1 TrainingPlanRepositoryImplTests

```swift
// HavitalTests/TrainingPlan/Unit/Repository/TrainingPlanRepositoryImplTests.swift
final class TrainingPlanRepositoryImplTests: XCTestCase {
    var sut: TrainingPlanRepositoryImpl!
    var mockRemoteDataSource: MockTrainingPlanRemoteDataSource!
    var mockLocalDataSource: MockTrainingPlanLocalDataSource!

    override func setUp() {
        super.setUp()
        mockRemoteDataSource = MockTrainingPlanRemoteDataSource()
        mockLocalDataSource = MockTrainingPlanLocalDataSource()
        sut = TrainingPlanRepositoryImpl(
            remoteDataSource: mockRemoteDataSource,
            localDataSource: mockLocalDataSource
        )
    }

    // MARK: - Cache Hit Tests

    func testGetWeeklyPlan_CacheHit_ReturnsCachedData() async throws {
        // Given
        let planId = "plan_123_1"
        let cachedPlan = TrainingPlanFixtures.weeklyPlan1

        mockLocalDataSource.cachedWeeklyPlans[planId] = cachedPlan
        mockLocalDataSource.expirationStatus[planId] = false  // 未過期

        // When
        let result = try await sut.getWeeklyPlan(planId: planId)

        // Then
        XCTAssertEqual(result.id, cachedPlan.id)
        XCTAssertEqual(mockRemoteDataSource.getWeeklyPlanCallCount, 0)  // 不應該調用 API
        XCTAssertTrue(mockLocalDataSource.getWeeklyPlanCalled)
    }

    // MARK: - Cache Miss Tests

    func testGetWeeklyPlan_CacheMiss_FetchesFromAPI() async throws {
        // Given
        let planId = "plan_123_1"
        let apiPlan = TrainingPlanFixtures.weeklyPlan1

        mockLocalDataSource.cachedWeeklyPlans[planId] = nil  // 無緩存
        mockRemoteDataSource.weeklyPlanToReturn = apiPlan

        // When
        let result = try await sut.getWeeklyPlan(planId: planId)

        // Then
        XCTAssertEqual(result.id, apiPlan.id)
        XCTAssertEqual(mockRemoteDataSource.getWeeklyPlanCallCount, 1)  // 應該調用 API
        XCTAssertTrue(mockLocalDataSource.saveWeeklyPlanCalled)  // 應該保存緩存
    }

    // MARK: - Cache Expiration Tests

    func testGetWeeklyPlan_CacheExpired_FetchesFromAPI() async throws {
        // Given
        let planId = "plan_123_1"
        let cachedPlan = TrainingPlanFixtures.weeklyPlan1
        let freshPlan = TrainingPlanFixtures.weeklyPlan1  // 可以修改一些屬性表示新數據

        mockLocalDataSource.cachedWeeklyPlans[planId] = cachedPlan
        mockLocalDataSource.expirationStatus[planId] = true  // 已過期
        mockRemoteDataSource.weeklyPlanToReturn = freshPlan

        // When
        let result = try await sut.getWeeklyPlan(planId: planId)

        // Then
        XCTAssertEqual(result.id, freshPlan.id)
        XCTAssertEqual(mockRemoteDataSource.getWeeklyPlanCallCount, 1)  // 應該調用 API
    }

    // MARK: - Background Refresh Tests

    func testGetWeeklyPlan_CacheHit_TriggersBackgroundRefresh() async throws {
        // Given
        let planId = "plan_123_1"
        let cachedPlan = TrainingPlanFixtures.weeklyPlan1

        mockLocalDataSource.cachedWeeklyPlans[planId] = cachedPlan
        mockLocalDataSource.expirationStatus[planId] = false

        // When
        _ = try await sut.getWeeklyPlan(planId: planId)

        // Wait for background task
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 秒

        // Then
        // 背景刷新應該被觸發（這需要在 Mock 中記錄）
        // 注意：測試背景任務比較複雜，可能需要使用 expectation
    }

    // MARK: - Create Tests

    func testCreateWeeklyPlan_SavesAndInvalidatesCache() async throws {
        // Given
        let week = 2
        let newPlan = TrainingPlanFixtures.weeklyPlan1
        mockRemoteDataSource.weeklyPlanToReturn = newPlan

        // When
        let result = try await sut.createWeeklyPlan(
            week: week,
            startFromStage: nil,
            isBeginner: false
        )

        // Then
        XCTAssertEqual(result.id, newPlan.id)
        XCTAssertTrue(mockLocalDataSource.saveWeeklyPlanCalled)
        XCTAssertTrue(mockLocalDataSource.removePlanStatusCalled)  // 應該使 plan status 失效
    }
}
```

**測試覆蓋**:
- ✅ 緩存命中（Cache Hit）
- ✅ 緩存未命中（Cache Miss）
- ✅ 緩存過期（Cache Expired）
- ✅ 背景刷新機制
- ✅ 創建時使緩存失效
- ✅ 錯誤轉換（HTTPError → DomainError）

### 階段 4: ViewModel 單元測試（2-3 小時）

```swift
// HavitalTests/TrainingPlan/Unit/ViewModel/TrainingPlanViewModelTests.swift
final class TrainingPlanViewModelTests: XCTestCase {
    var sut: TrainingPlanViewModel!
    var mockRepository: MockTrainingPlanRepository!

    @MainActor
    override func setUp() {
        super.setUp()
        mockRepository = MockTrainingPlanRepository()
        sut = TrainingPlanViewModel(repository: mockRepository)
    }

    @MainActor
    func testLoadPlanStatus_Success_UpdatesProperties() async {
        // Given
        let expectedStatus = TrainingPlanFixtures.planStatus
        mockRepository.planStatusToReturn = expectedStatus

        // When
        await sut.loadPlanStatus()

        // Then
        XCTAssertEqual(mockRepository.getPlanStatusCallCount, 1)
        // 驗證 ViewModel 的屬性是否正確更新
    }

    @MainActor
    func testLoadWeeklyPlan_Success_UpdatesUI() async {
        // Given
        let expectedPlan = TrainingPlanFixtures.weeklyPlan1
        mockRepository.weeklyPlanToReturn = expectedPlan

        // When
        await sut.performLoadWeeklyPlan()

        // Then
        XCTAssertNotNil(sut.weeklyPlan)
        XCTAssertEqual(sut.weeklyPlan?.id, expectedPlan.id)
    }
}
```

### 階段 5: 集成測試（2-3 小時）

```swift
// HavitalTests/TrainingPlan/Integration/TrainingPlanViewModelIntegrationTests.swift
final class TrainingPlanViewModelIntegrationTests: XCTestCase {
    var sut: TrainingPlanViewModel!
    var repository: TrainingPlanRepositoryImpl!
    var mockHTTPClient: MockHTTPClient!
    var mockUserDefaults: MockUserDefaults!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()

        // 設置真實的依賴（除了 HTTP 和 UserDefaults）
        mockHTTPClient = MockHTTPClient()
        mockUserDefaults = MockUserDefaults()

        let remoteDataSource = TrainingPlanRemoteDataSource(
            httpClient: mockHTTPClient,
            parser: DefaultAPIParser.shared
        )
        let localDataSource = TrainingPlanLocalDataSource(
            defaults: mockUserDefaults
        )

        repository = TrainingPlanRepositoryImpl(
            remoteDataSource: remoteDataSource,
            localDataSource: localDataSource
        )

        sut = TrainingPlanViewModel(repository: repository)
    }

    @MainActor
    func testCompleteUserFlow_LoadPlanStatus_Then_LoadWeeklyPlan() async throws {
        // Given - 設置 API 響應
        let statusData = try JSONEncoder().encode(TrainingPlanFixtures.planStatus)
        let planData = try JSONEncoder().encode(TrainingPlanFixtures.weeklyPlan1)

        mockHTTPClient.mockResponses["GET:/plan/race_run/status"] = .success(statusData)
        mockHTTPClient.mockResponses["GET:/plan/race_run/weekly/plan_123_1"] = .success(planData)

        // When - 執行完整流程
        await sut.loadPlanStatus()
        await sut.performLoadWeeklyPlan()

        // Then - 驗證結果
        XCTAssertNotNil(sut.weeklyPlan)
        XCTAssertEqual(mockHTTPClient.requestHistory.count, 2)
    }
}
```

## 測試覆蓋率目標

| 層級 | 目標覆蓋率 | 關鍵指標 |
|------|-----------|---------|
| LocalDataSource | 95%+ | 緩存邏輯完整覆蓋 |
| RemoteDataSource | 90%+ | 所有 API 端點覆蓋 |
| Repository | 85%+ | 緩存策略和錯誤處理 |
| ViewModel | 70%+ | 主要用戶流程覆蓋 |
| **整體** | **80%+** | TrainingPlan 模組 |

## 持續集成建議

### Git Hooks (Pre-commit)

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "🧪 運行 TrainingPlan 單元測試..."
./Scripts/test_training_plan.sh unit

if [ $? -ne 0 ]; then
    echo "❌ 測試失敗，無法提交"
    exit 1
fi

echo "✅ 測試通過，繼續提交"
```

### CI/CD Pipeline

```yaml
# .github/workflows/test.yml
name: TrainingPlan Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Tests
        run: ./Scripts/test_training_plan.sh all --clean
      - name: Upload Coverage
        uses: codecov/codecov-action@v2
```

## 測試最佳實踐

### 1. AAA 模式（Arrange-Act-Assert）
```swift
func testExample() {
    // Arrange - 準備測試數據
    let input = "test"

    // Act - 執行被測試的操作
    let result = sut.process(input)

    // Assert - 驗證結果
    XCTAssertEqual(result, "expected")
}
```

### 2. Given-When-Then 註釋
```swift
func testExample() {
    // Given - 給定初始條件

    // When - 當執行某操作

    // Then - 則應該得到某結果
}
```

### 3. 測試命名規範
```swift
// 格式: test[方法名]_[輸入條件]_[預期結果]
func testGetWeeklyPlan_CacheHit_ReturnsCachedData()
func testGetWeeklyPlan_CacheMiss_FetchesFromAPI()
func testCreateWeeklyPlan_ValidInput_ReturnsNewPlan()
```

### 4. 使用 Mock 而非 Stub
- **Mock**: 記錄調用歷史，可驗證交互
- **Stub**: 只提供預設響應

### 5. 隔離測試
- 每個測試獨立運行
- setUp/tearDown 清理狀態
- 不依賴測試執行順序

## 時間估算

| 階段 | 預計時間 | 產出 |
|------|---------|------|
| Mock 層 | 1-2 小時 | 3-4 個 Mock 類 |
| DataSource 測試 | 2-3 小時 | 20+ 測試用例 |
| Repository 測試 | 3-4 小時 | 15+ 測試用例 |
| ViewModel 測試 | 2-3 小時 | 10+ 測試用例 |
| 集成測試 | 2-3 小時 | 5+ 測試用例 |
| **總計** | **10-15 小時** | **50+ 測試用例** |

## 下一步

1. 創建 Mock 類
2. 實現 DataSource 測試
3. 實現 Repository 測試
4. 實現 ViewModel 測試
5. 實現集成測試
6. 配置 CI/CD
