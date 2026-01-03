# 集成測試框架 - 實現總結

**日期**: 2026-01-01
**目標**: 創建可本地執行、呼叫真實 API 的集成測試，驗證 managers → domain layer 重構正確性

---

## ✅ 已完成的工作

### 1. 核心框架

#### ✅ IntegrationTestBase.swift
**位置**: `HavitalTests/Integration/IntegrationTestBase.swift`

**功能**:
- ✅ 自動 Demo 登錄獲取認證 token
- ✅ 環境保護（只能在 DEBUG 配置下運行）
- ✅ 提供便利方法獲取 Repository 和 UseCase
- ✅ 測試日誌記錄（logTestStart/logTestEnd）

**關鍵特性**:
```swift
override class func setUp() {
    // 驗證環境
    guard APIConfig.isDevelopment else {
        fatalError("❌ 集成測試必須在 DEBUG 配置下運行！")
    }

    // Demo 登錄
    let response = try await EmailAuthService.shared.demoLogin()
    demoToken = response.data.idToken
}
```

### 2. Repository 層測試

#### ✅ TrainingPlanRepositoryIntegrationTests.swift
**位置**: `HavitalTests/Integration/Repositories/TrainingPlanRepositoryIntegrationTests.swift`

**測試覆蓋** (6 個測試):
1. ✅ `test_getOverview_shouldReturnValidData` - 獲取訓練計劃概覽
2. ✅ `test_getWeeklyPlan_withValidPlanId_shouldReturnValidData` - 獲取週計劃
3. ✅ `test_getPlanStatus_shouldReturnValidStatus` - 獲取計劃狀態
4. ✅ `test_refreshWeeklyPlan_shouldReturnLatestData` - 刷新週計劃
5. ✅ `test_getCurrentWeek_shouldReturnValidWeek` - 獲取當前週數
6. ✅ `test_getWeeklyPlan_withInvalidPlanId_shouldThrowError` - 錯誤處理

**驗證內容**:
- ✅ Repository → RemoteDataSource → HTTPClient → 真實 API
- ✅ 數據正確性（ID、距離、週次等）
- ✅ 錯誤處理機制

### 3. UseCase 層測試

#### ✅ TrainingPlanUseCaseIntegrationTests.swift
**位置**: `HavitalTests/Integration/UseCases/TrainingPlanUseCaseIntegrationTests.swift`

**測試覆蓋** (4 個測試):
1. ✅ `test_getTrainingOverviewUseCase_shouldReturnValidData` - UseCase 獲取概覽
2. ✅ `test_getWeeklyPlanUseCase_shouldReturnValidData` - UseCase 獲取週計劃
3. ✅ `test_generateNewWeekPlanUseCase_shouldGenerateNewPlan` - UseCase 生成新計劃
4. ✅ `test_completeDataFlow_useCaseToAPI_shouldWork` - 完整數據流驗證

**驗證內容**:
- ✅ UseCase → Repository → API 完整流程
- ✅ 業務邏輯正確性
- ✅ DependencyContainer 依賴注入

### 4. 端到端測試

#### ✅ TrainingPlanFlowIntegrationTests.swift
**位置**: `HavitalTests/Integration/EndToEnd/TrainingPlanFlowIntegrationTests.swift`

**測試場景** (3 個測試):
1. ✅ `test_userViewTrainingPlan_completeFlow` - 用戶查看訓練計劃完整流程
2. ✅ `test_dualTrackCaching_completeFlow` - 雙軌緩存策略驗證
3. ✅ `test_errorHandling_completeFlow` - 錯誤處理機制驗證

**驗證內容**:
- ✅ 模擬真實用戶場景
- ✅ Cache-First + Background Refresh 策略
- ✅ 端到端錯誤處理

### 5. 執行腳本

#### ✅ run_integration_tests.sh
**位置**: `Scripts/run_integration_tests.sh`

**功能**:
- ✅ 環境驗證（網路、Simulator）
- ✅ 可選緩存清理
- ✅ 自動運行集成測試
- ✅ 生成詳細測試報告
- ✅ 支持篩選特定測試類
- ✅ 詳細日誌模式

**使用方式**:
```bash
# 運行所有集成測試
./Scripts/run_integration_tests.sh

# 運行特定測試類
./Scripts/run_integration_tests.sh --filter TrainingPlanRepositoryIntegrationTests

# 詳細日誌
./Scripts/run_integration_tests.sh -v
```

#### ✅ verify_integration_tests.sh
**位置**: `Scripts/verify_integration_tests.sh`

**功能**:
- ✅ 快速驗證文件結構
- ✅ 編譯檢查（不執行測試）
- ✅ 確保代碼無語法錯誤

### 6. 文檔

#### ✅ INTEGRATION_TESTS_GUIDE.md
**位置**: `Docs/INTEGRATION_TESTS_GUIDE.md`

**內容**:
- ✅ 快速開始指南
- ✅ 測試結構說明
- ✅ 測試覆蓋範圍
- ✅ 高級用法
- ✅ 如何添加新測試
- ✅ 常見問題解答

#### ✅ HavitalTests/Integration/README.md
**位置**: `HavitalTests/Integration/README.md`

**內容**:
- ✅ 快速參考
- ✅ 測試目錄結構
- ✅ 測試覆蓋概覽
- ✅ 快速上手示例

---

## 📊 測試統計

### 測試數量
- **Repository 層**: 6 個測試
- **UseCase 層**: 4 個測試
- **端到端**: 3 個測試
- **總計**: **13 個集成測試**

### 覆蓋範圍
- ✅ **HTTPClient 層** - 真實 API 通信
- ✅ **RemoteDataSource 層** - API 調用封裝
- ✅ **Repository 層** - 數據協調與緩存
- ✅ **UseCase 層** - 業務邏輯執行
- ✅ **完整數據流** - 端到端驗證

---

## 🎯 架構設計

### 測試分層

```
HavitalTests/
├── Integration/                          # 集成測試（真實 API）
│   ├── IntegrationTestBase.swift        # 基礎類
│   ├── Repositories/                     # Repository 層
│   ├── UseCases/                        # UseCase 層
│   └── EndToEnd/                        # 端到端
└── Unit/                                 # 單元測試（Mock 對象）
    ├── Managers/
    └── Domain/
```

### 關鍵設計決策

1. **方案選擇**: 混合方案（方案 3）
   - ✅ 不需要新 Test Target
   - ✅ 清晰分離單元測試和集成測試
   - ✅ 使用環境變量保護
   - ✅ 靈活的執行選項

2. **認證方式**: Demo 帳號
   - ✅ 無需真實 Firebase 帳號
   - ✅ 自動登錄流程
   - ✅ IntegrationTestBase 統一處理

3. **API 環境**: 開發環境 (DEBUG)
   - ✅ Base URL: `https://api-service-364865009192.asia-east1.run.app`
   - ✅ 環境保護機制
   - ✅ 不會影響生產數據

4. **執行方式**: xcodebuild 命令行
   - ✅ 本地可執行腳本
   - ✅ 適合 CI/CD 集成
   - ✅ 詳細測試報告

---

## 🔧 技術亮點

### 1. 環境保護機制

```swift
guard APIConfig.isDevelopment else {
    fatalError("❌ 集成測試必須在 DEBUG 配置下運行！")
}
```

確保：
- ✅ 不會在 RELEASE 配置下執行
- ✅ 不會調用生產環境 API
- ✅ 安全可靠

### 2. 自動認證流程

```swift
override class func setUp() {
    // 自動 Demo 登錄
    let response = try await EmailAuthService.shared.demoLogin()
    demoToken = response.data.idToken
    isAuthenticated = true
}
```

無需手動配置，完全自動化。

### 3. DependencyContainer 集成

```swift
func getRepository<T>() -> T {
    return DependencyContainer.shared.resolve()
}

func getUseCase<T>() -> T {
    return DependencyContainer.shared.resolve()
}
```

利用已有的依賴注入系統，無需 Mock 對象。

### 4. 詳細日誌記錄

```swift
func logTestStart(_ testName: String) {
    print("\n" + String(repeating: "=", 60))
    print("🧪 測試開始: \(testName)")
    print(String(repeating: "=", 60))
}
```

清晰的測試進度追蹤。

---

## ✅ 驗證標準

集成測試通過表示：

1. ✅ **Repository 層正確** - 與真實 API 交互無誤
2. ✅ **UseCase 層正確** - 業務邏輯執行正確
3. ✅ **數據流正確** - 端到端數據傳遞無誤
4. ✅ **重構成功** - Managers → Domain Layer 遷移成功
5. ✅ **雙軌緩存正確** - Cache-First + Background Refresh 正常工作

---

## 📝 使用說明

### 快速開始

```bash
cd /Users/wubaizong/havital/apps/ios/Havital

# 一鍵執行
./Scripts/run_integration_tests.sh
```

### 查看報告

```bash
# 查看最新報告
cat integration_test_report_*.txt | tail -50

# 查看完整日誌
cat integration_test_output.log
```

---

## 🎓 擴展指南

### 為其他 Feature 添加集成測試

1. **創建 Repository 測試**:
```swift
@MainActor
final class YourRepositoryIntegrationTests: IntegrationTestBase {
    var repository: YourRepository!

    override func setUp() async throws {
        try await super.setUp()
        ensureAuthenticated()
        repository = getRepository()
    }

    func test_yourMethod() async throws {
        logTestStart("測試功能")
        let result = try await repository.yourMethod()
        XCTAssertNotNil(result)
        logTestEnd("測試功能", success: true)
    }
}
```

2. **添加到執行腳本**:
編輯 `Scripts/run_integration_tests.sh`，添加：
```bash
TEST_CMD_ARGS+=("-only-testing:HavitalTests/YourRepositoryIntegrationTests")
```

3. **運行測試**:
```bash
./Scripts/run_integration_tests.sh --filter YourRepositoryIntegrationTests
```

---

## 🐛 已修復的問題

### Issue 1: xcodebuild destination 參數格式錯誤

**問題**:
```bash
xcodebuild: error: option 'Destination' requires at least one parameter
```

**原因**: Shell 腳本中單引號被當成字面字符

**修復**:
```bash
# ❌ 錯誤
TEST_CMD+=" -destination 'platform=iOS Simulator,name=$SIMULATOR_NAME'"

# ✅ 正確
TEST_CMD_ARGS+=("-destination" "platform=iOS Simulator,name=$SIMULATOR_NAME")
```

---

## 🎯 成功標準

### 代碼質量
- ✅ 所有測試文件編譯通過
- ✅ 無語法錯誤
- ✅ 遵循項目架構規範

### 功能完整性
- ✅ 13 個集成測試全部實現
- ✅ 覆蓋 Repository、UseCase、EndToEnd 三層
- ✅ 執行腳本功能完整

### 文檔完整性
- ✅ 快速開始指南
- ✅ 詳細使用文檔
- ✅ 擴展指南
- ✅ 常見問題解答

---

## 📚 相關文件

### 測試代碼
- `HavitalTests/Integration/IntegrationTestBase.swift`
- `HavitalTests/Integration/Repositories/TrainingPlanRepositoryIntegrationTests.swift`
- `HavitalTests/Integration/UseCases/TrainingPlanUseCaseIntegrationTests.swift`
- `HavitalTests/Integration/EndToEnd/TrainingPlanFlowIntegrationTests.swift`

### 執行腳本
- `Scripts/run_integration_tests.sh` - 主執行腳本
- `Scripts/verify_integration_tests.sh` - 編譯驗證腳本

### 文檔
- `Docs/INTEGRATION_TESTS_GUIDE.md` - 完整使用指南
- `HavitalTests/Integration/README.md` - 快速參考

---

## 🎉 總結

成功創建了完整的集成測試框架，實現了：

✅ **13 個集成測試** - 覆蓋完整數據流
✅ **自動化執行** - 一鍵本地運行
✅ **真實 API 驗證** - 確保重構正確性
✅ **完整文檔** - 快速上手和擴展
✅ **環境保護** - 安全可靠

**下一步建議**:
1. 為其他 Feature 添加集成測試（Target, User, Workout, VDOT, etc.）
2. 集成到 CI/CD 流程
3. 設置自動化測試報告
4. 增加性能測試和壓力測試

---

**創建日期**: 2026-01-01
**版本**: 1.0
**狀態**: ✅ 完成
