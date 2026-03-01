# 集成測試 - Integration Tests

## 📖 快速開始

```bash
cd /Users/wubaizong/havital/apps/ios/Havital

# 一鍵執行所有集成測試
./Scripts/run_integration_tests.sh
```

## 📂 測試目錄結構

```
Integration/
├── README.md                             # 本文件
├── IntegrationTestBase.swift            # 基礎測試類（Demo 登錄、環境驗證）
├── Repositories/                         # Repository 層集成測試
│   └── TrainingPlanRepositoryIntegrationTests.swift
├── UseCases/                            # UseCase 層集成測試
│   └── TrainingPlanUseCaseIntegrationTests.swift
└── EndToEnd/                            # 端到端測試
    └── TrainingPlanFlowIntegrationTests.swift
```

## ✅ 測試特性

- ✅ **真實 API 調用** - 驗證與後端的實際交互
- ✅ **自動 Demo 登錄** - 無需手動配置認證
- ✅ **環境保護** - 只能在 DEBUG 配置下運行
- ✅ **完整數據流** - UseCase → Repository → RemoteDataSource → HTTPClient → API
- ✅ **詳細日誌** - 每個測試都有清晰的輸出

## 🎯 測試覆蓋

### Repository 層（6 個測試）
1. ✅ 獲取訓練計劃概覽
2. ✅ 獲取週計劃
3. ✅ 獲取計劃狀態
4. ✅ 刷新週計劃
5. ✅ 獲取當前週數
6. ✅ 錯誤處理（無效 Plan ID）

### UseCase 層（4 個測試）
1. ✅ GetTrainingOverviewUseCase
2. ✅ GetWeeklyPlanUseCase
3. ✅ GenerateNewWeekPlanUseCase
4. ✅ 完整數據流驗證

### 端到端（3 個測試）
1. ✅ 用戶查看訓練計劃完整流程
2. ✅ 雙軌緩存策略驗證
3. ✅ 錯誤處理機制驗證

**總計**: 13 個集成測試

## 🔧 高級用法

### 運行特定測試類

```bash
# Repository 層測試
./Scripts/run_integration_tests.sh --filter TrainingPlanRepositoryIntegrationTests

# UseCase 層測試
./Scripts/run_integration_tests.sh --filter TrainingPlanUseCaseIntegrationTests

# 端到端測試
./Scripts/run_integration_tests.sh --filter TrainingPlanFlowIntegrationTests
```

### 詳細日誌模式

```bash
./Scripts/run_integration_tests.sh -v
```

## 📝 添加新測試

1. 繼承 `IntegrationTestBase`
2. 在 `setUp()` 中調用 `ensureAuthenticated()`
3. 使用 `getRepository()` 或 `getUseCase()` 獲取依賴
4. 使用 `logTestStart()` 和 `logTestEnd()` 記錄測試過程

```swift
@MainActor
final class YourIntegrationTests: IntegrationTestBase {
    var repository: YourRepository!

    override func setUp() async throws {
        try await super.setUp()
        ensureAuthenticated()
        repository = getRepository()
    }

    func test_yourFeature() async throws {
        logTestStart("測試功能")

        // 測試邏輯
        let result = try await repository.yourMethod()
        XCTAssertNotNil(result)

        logTestEnd("測試功能", success: true)
    }
}
```

## 📚 完整文檔

詳細使用指南: [Docs/INTEGRATION_TESTS_GUIDE.md](../../Docs/INTEGRATION_TESTS_GUIDE.md)

## ⚠️ 重要提醒

- ⚠️ 集成測試調用**真實 API**
- ⚠️ 必須在 **DEBUG 配置**下運行
- ⚠️ 需要**網路連接**
- ⚠️ 使用**開發環境** API（不是生產環境）

---

**問題反饋**: 如果遇到問題，請查看 `integration_test_output.log` 獲取詳細錯誤信息
