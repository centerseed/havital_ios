# 快速開始指南

本指南幫助你快速開始使用新的 Clean Architecture 和測試框架。

## 📋 目錄

1. [測試腳本使用](#測試腳本使用)
2. [創建新測試](#創建新測試)
3. [實現 Mock](#實現-mock)
4. [常見任務](#常見任務)

## 🧪 測試腳本使用

### 基本命令

```bash
cd /Users/wubaizong/havital/apps/ios/Havital

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

### 輸出示例

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TrainingPlan 模組測試套件
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

測試類型: repository

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  檢查依賴
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ xcodebuild 已安裝
✅ xcrun 已安裝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  運行測試: Repository 測試
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ️  執行測試中...
✅ 測試通過: Repository 測試

📊 測試統計:
  ✓ 通過測試數: 15
  ⏱  執行時間: 3.2s

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  生成覆蓋率報告
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📈 TrainingPlan 模組覆蓋率:
TrainingPlanRepositoryImpl.swift: 87.5%
TrainingPlanRemoteDataSource.swift: 92.3%
TrainingPlanLocalDataSource.swift: 95.1%

✅ 覆蓋率報告生成完成

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  測試完成
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ 所有測試執行完畢！
```

## 📝 創建新測試

### 步驟 1: 創建測試文件

```bash
# 在 HavitalTests/TrainingPlan/Unit/Repository/ 目錄下
touch HavitalTests/TrainingPlan/Unit/Repository/NewFeatureTests.swift
```

### 步驟 2: 編寫測試

```swift
import XCTest
@testable import Havital

final class NewFeatureTests: XCTestCase {
    var sut: YourClassUnderTest!
    var mockDependency: MockDependency!

    override func setUp() {
        super.setUp()
        mockDependency = MockDependency()
        sut = YourClassUnderTest(dependency: mockDependency)
    }

    override func tearDown() {
        sut = nil
        mockDependency = nil
        super.tearDown()
    }

    func testFeature_ValidInput_ReturnsExpectedOutput() {
        // Given - 準備測試數據
        let input = "test"

        // When - 執行操作
        let result = sut.process(input)

        // Then - 驗證結果
        XCTAssertEqual(result, "expected")
    }
}
```

### 步驟 3: 運行測試

```bash
./Scripts/test_training_plan.sh all
```

## 🎭 實現 Mock

### Mock HTTPClient 示例

```swift
// HavitalTests/TrainingPlan/Mocks/MockHTTPClient.swift
import Foundation
@testable import Havital

final class MockHTTPClient: HTTPClient {
    // 配置響應
    var mockResponses: [String: Result<Data, Error>] = [:]

    // 記錄調用歷史
    var requestHistory: [(path: String, method: HTTPMethod, body: Data?)] = []

    func request(path: String, method: HTTPMethod, body: Data?) async throws -> Data {
        // 記錄請求
        requestHistory.append((path, method, body))

        // 返回響應
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

### 使用 Mock

```swift
func testAPICall_Success() async throws {
    // Given
    let mockClient = MockHTTPClient()
    let expectedData = """
    {"id": "123", "name": "Test"}
    """.data(using: .utf8)!

    mockClient.mockResponses["GET:/api/test"] = .success(expectedData)

    let dataSource = MyDataSource(httpClient: mockClient)

    // When
    let result = try await dataSource.fetchData()

    // Then
    XCTAssertEqual(result.id, "123")
    XCTAssertEqual(mockClient.requestHistory.count, 1)
}
```

## 🛠 常見任務

### 任務 1: 添加新的 Repository 方法

#### 1. 在協議中添加方法

```swift
// Features/TrainingPlan/Domain/Repositories/TrainingPlanRepository.swift
protocol TrainingPlanRepository {
    // 新增
    func getNewFeature(id: String) async throws -> NewFeature
}
```

#### 2. 在 RemoteDataSource 中實現 API 調用

```swift
// Features/TrainingPlan/Data/DataSources/TrainingPlanRemoteDataSource.swift
func getNewFeature(id: String) async throws -> NewFeature {
    let rawData = try await httpClient.request(
        path: "/api/new-feature/\(id)",
        method: .GET
    )
    return try ResponseProcessor.extractData(
        NewFeature.self,
        from: rawData,
        using: parser
    )
}
```

#### 3. 在 LocalDataSource 中添加緩存

```swift
// Features/TrainingPlan/Data/DataSources/TrainingPlanLocalDataSource.swift
private enum Keys {
    static let newFeaturePrefix = "new_feature_v1_"
}

func saveNewFeature(_ feature: NewFeature, id: String) {
    let key = Keys.newFeaturePrefix + id
    // ... 緩存邏輯
}

func getNewFeature(id: String) -> NewFeature? {
    let key = Keys.newFeaturePrefix + id
    // ... 讀取邏輯
}
```

#### 4. 在 RepositoryImpl 中實現雙軌緩存

```swift
// Features/TrainingPlan/Data/Repositories/TrainingPlanRepositoryImpl.swift
func getNewFeature(id: String) async throws -> NewFeature {
    Logger.debug("[Repository] getNewFeature: \(id)")

    // Track A: 緩存
    if let cached = localDataSource.getNewFeature(id: id),
       !localDataSource.isNewFeatureExpired(id: id) {
        Logger.debug("[Repository] Cache hit")

        // Track B: 背景刷新
        Task.detached(priority: .background) { [weak self] in
            await self?.refreshNewFeatureInBackground(id: id)
        }

        return cached
    }

    // 無緩存
    return try await fetchAndCacheNewFeature(id: id)
}

private func fetchAndCacheNewFeature(id: String) async throws -> NewFeature {
    let feature = try await remoteDataSource.getNewFeature(id: id)
    localDataSource.saveNewFeature(feature, id: id)
    return feature
}
```

#### 5. 在 ViewModel 中使用

```swift
// ViewModels/TrainingPlanViewModel.swift
func loadNewFeature() async {
    do {
        let feature = try await trainingPlanRepository.getNewFeature(id: "123")
        // 更新 UI
    } catch {
        // 錯誤處理
    }
}
```

#### 6. 編寫測試

```swift
// HavitalTests/TrainingPlan/Unit/Repository/NewFeatureTests.swift
func testGetNewFeature_CacheHit_ReturnsCachedData() async throws {
    // Given
    let id = "123"
    let cached = NewFeature(id: id, name: "Test")
    mockLocal.cachedFeatures[id] = cached
    mockLocal.expirationStatus[id] = false

    // When
    let result = try await sut.getNewFeature(id: id)

    // Then
    XCTAssertEqual(result.id, cached.id)
    XCTAssertEqual(mockRemote.getNewFeatureCallCount, 0)
}
```

### 任務 2: 調試失敗的測試

#### 1. 查看詳細日誌

```bash
# 運行測試並保存完整日誌
./Scripts/test_training_plan.sh all 2>&1 | tee test_log.txt
```

#### 2. 添加斷點

```swift
func testExample() {
    let result = sut.process(input)

    // 添加斷點檢查值
    print("DEBUG: result = \(result)")

    XCTAssertEqual(result, expected)
}
```

#### 3. 檢查 Mock 調用歷史

```swift
func testExample() {
    // When
    _ = try await dataSource.fetchData()

    // Then - 檢查 Mock 是否被正確調用
    print("Request history: \(mockClient.requestHistory)")
    XCTAssertEqual(mockClient.requestHistory.count, 1)
    XCTAssertEqual(mockClient.requestHistory[0].path, "/expected/path")
}
```

### 任務 3: 提升測試覆蓋率

#### 1. 生成覆蓋率報告

```bash
./Scripts/test_training_plan.sh all

# 查看詳細報告
xcrun xccov view --report DerivedData/Logs/Test/*.xcresult
```

#### 2. 找出未覆蓋的代碼

```bash
# 過濾特定文件
xcrun xccov view --report DerivedData/Logs/Test/*.xcresult | \
grep "TrainingPlanRepository"
```

#### 3. 添加缺失的測試

```swift
// 為未覆蓋的分支添加測試
func testEdgeCase_NullInput_ThrowsError() {
    // Given
    let input: String? = nil

    // When/Then
    XCTAssertThrowsError(try sut.process(input))
}
```

### 任務 4: 性能測試

```swift
func testPerformance_LoadLargePlan() {
    let largePlan = createLargePlan(days: 365)

    measure {
        // 測試代碼
        _ = sut.process(largePlan)
    }
}
```

## 📚 更多資源

- [完整測試策略](04-TESTING-STRATEGY.md)
- [遷移模式指南](05-MIGRATION-PATTERN.md)
- [遷移路線圖](03-MIGRATION-ROADMAP.md)

## 🆘 常見問題

### Q: 測試腳本運行失敗

**檢查清單**:
1. 確認 Xcode 已安裝
2. 確認模擬器已安裝
3. 嘗試添加 `--clean` 標誌
4. 檢查測試目標是否正確

### Q: Mock 不工作

**檢查**:
1. Mock 是否正確注入
2. Mock 響應是否已配置
3. 請求 key 是否匹配（注意大小寫）

### Q: 測試通過但覆蓋率低

**解決**:
1. 添加邊界條件測試
2. 添加錯誤情況測試
3. 添加異步操作測試

## 🎯 下一步

1. 閱讀 [測試策略文檔](04-TESTING-STRATEGY.md)
2. 實現你的第一個測試
3. 運行 `./Scripts/test_training_plan.sh`
4. 查看覆蓋率報告
5. 持續改進！
