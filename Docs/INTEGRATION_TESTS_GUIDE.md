# 集成測試使用指南

## 📖 概述

集成測試框架用於驗證 **managers → domain layer** 重構的正確性，通過呼叫真實 API 來確保：
- ✅ Repository 層與後端 API 正常交互
- ✅ UseCase 層業務邏輯正確執行
- ✅ 完整數據流（UseCase → Repository → RemoteDataSource → HTTPClient → API）正常工作
- ✅ 雙軌緩存策略正確實現

## 🚀 快速開始

### 一鍵執行

```bash
cd /Users/wubaizong/havital/apps/ios/Havital

# 運行所有集成測試
./Scripts/run_integration_tests.sh
```

**執行過程**：
1. ✅ 環境驗證（網路、Simulator）
2. 🔐 自動 Demo 登錄獲取認證 token
3. 🧪 執行所有集成測試
4. 📊 生成測試報告

### 預期輸出

```
🧪 ========================================
🧪 集成測試 - 真實 API 驗證
🧪 ========================================

步驟 1: 環境驗證
✅ 網路連接正常
✅ Simulator 就緒

步驟 2: 運行集成測試
🔐 Demo 登錄成功
🧪 執行測試中...

✅ 集成測試全部通過！

📊 測試統計:
   - 測試數量: 12
   - 執行時間: 15 秒
   - API 環境: 開發環境 (DEBUG)

✅ 重構驗證成功
```

## 📂 測試結構

```
HavitalTests/
├── Integration/                          # 集成測試目錄
│   ├── IntegrationTestBase.swift        # 基礎測試類（處理 Demo 登錄）
│   ├── Repositories/                     # Repository 層測試
│   │   └── TrainingPlanRepositoryIntegrationTests.swift
│   ├── UseCases/                        # UseCase 層測試
│   │   └── TrainingPlanUseCaseIntegrationTests.swift
│   └── EndToEnd/                        # 端到端測試
│       └── TrainingPlanFlowIntegrationTests.swift
└── Unit/                                 # 單元測試目錄（Mock 對象）
    ├── Managers/
    └── Domain/
```

## 🎯 測試覆蓋範圍

### 1. Repository 層集成測試

**文件**: `TrainingPlanRepositoryIntegrationTests.swift`

測試內容：
- ✅ `test_getOverview_shouldReturnValidData` - 獲取訓練計劃概覽
- ✅ `test_getWeeklyPlan_withValidPlanId_shouldReturnValidData` - 獲取週計劃
- ✅ `test_getPlanStatus_shouldReturnValidStatus` - 獲取計劃狀態
- ✅ `test_refreshWeeklyPlan_shouldReturnLatestData` - 刷新週計劃
- ✅ `test_getCurrentWeek_shouldReturnValidWeek` - 獲取當前週數
- ✅ `test_getWeeklyPlan_withInvalidPlanId_shouldThrowError` - 錯誤處理

### 2. UseCase 層集成測試

**文件**: `TrainingPlanUseCaseIntegrationTests.swift`

測試內容：
- ✅ `test_getTrainingOverviewUseCase_shouldReturnValidData` - UseCase 獲取概覽
- ✅ `test_getWeeklyPlanUseCase_shouldReturnValidData` - UseCase 獲取週計劃
- ✅ `test_generateNewWeekPlanUseCase_shouldGenerateNewPlan` - UseCase 生成新計劃
- ✅ `test_completeDataFlow_useCaseToAPI_shouldWork` - 完整數據流驗證

### 3. 端到端測試

**文件**: `TrainingPlanFlowIntegrationTests.swift`

測試場景：
- ✅ `test_userViewTrainingPlan_completeFlow` - 用戶查看訓練計劃完整流程
- ✅ `test_dualTrackCaching_completeFlow` - 雙軌緩存策略驗證
- ✅ `test_errorHandling_completeFlow` - 錯誤處理機制驗證

## 🔧 高級用法

### 運行特定測試

```bash
# 只運行 Repository 層測試
./Scripts/run_integration_tests.sh --filter TrainingPlanRepositoryIntegrationTests

# 只運行 UseCase 層測試
./Scripts/run_integration_tests.sh --filter TrainingPlanUseCaseIntegrationTests

# 只運行端到端測試
./Scripts/run_integration_tests.sh --filter TrainingPlanFlowIntegrationTests
```

### 詳細輸出模式

```bash
# 顯示完整測試日誌
./Scripts/run_integration_tests.sh -v
```

### 清空緩存測試

```bash
# 執行時選擇清空緩存
./Scripts/run_integration_tests.sh
# 提示時輸入 'y' 清空緩存
```

## 🏗️ 如何添加新的集成測試

### 1. 創建測試類

```swift
//  YourFeatureRepositoryIntegrationTests.swift

import XCTest
@testable import Havital

@MainActor
final class YourFeatureRepositoryIntegrationTests: IntegrationTestBase {

    var repository: YourFeatureRepository!

    override func setUp() async throws {
        try await super.setUp()
        ensureAuthenticated()
        repository = getRepository()
    }

    func test_yourFeature_shouldWork() async throws {
        logTestStart("測試你的功能")

        do {
            // When: 調用真實 API
            let result = try await repository.yourMethod()

            // Then: 驗證結果
            XCTAssertNotNil(result)

            logTestEnd("測試你的功能", success: true)
        } catch {
            logTestEnd("測試你的功能", success: false)
            XCTFail("測試失敗: \(error)")
        }
    }
}
```

### 2. 在執行腳本中添加

編輯 `Scripts/run_integration_tests.sh`，添加你的測試類：

```bash
TEST_CMD+=" -only-testing:HavitalTests/YourFeatureRepositoryIntegrationTests"
```

## 📊 測試報告

每次執行後會生成兩個文件：

1. **integration_test_output.log** - 完整測試日誌
2. **integration_test_report_YYYYMMDD_HHMMSS.txt** - 測試報告摘要

查看報告：
```bash
# 查看最新報告
cat integration_test_report_*.txt | tail -50

# 查看完整日誌
cat integration_test_output.log
```

## ⚙️ 環境配置

### API 環境

集成測試使用 **開發環境 (DEBUG)**：
- Base URL: `https://api-service-364865009192.asia-east1.run.app`
- 配置文件: `Havital/Services/APIConfig.swift`

### 認證方式

使用 **Demo 帳號** 自動登錄：
- 不需要配置真實 Firebase 帳號
- 不需要手動輸入帳號密碼
- `IntegrationTestBase` 自動處理認證流程

### 環境保護

集成測試有以下保護機制：
```swift
// IntegrationTestBase.swift
guard APIConfig.isDevelopment else {
    fatalError("❌ 集成測試必須在 DEBUG 配置下運行！")
}
```

確保：
- ✅ 不會在 RELEASE 配置下執行
- ✅ 不會調用生產環境 API
- ✅ 使用測試專用的 Demo 帳號

## 🐛 常見問題

### Q1: Demo 登錄失敗？

**可能原因**：
- 網路連接問題
- 開發環境 API 服務異常

**解決方法**：
```bash
# 檢查網路
ping api-service-364865009192.asia-east1.run.app

# 檢查 API 環境配置
cat Havital/Services/APIConfig.swift
```

### Q2: 測試超時？

**可能原因**：
- API 響應慢
- 網路不穩定

**解決方法**：
- 增加超時時間（修改 `IntegrationTestBase.setUp()` 中的 `timeout` 參數）
- 檢查網路連接

### Q3: 測試失敗但單元測試通過？

**可能原因**：
- 後端 API 變更
- 數據格式不匹配

**解決方法**：
1. 查看 `integration_test_output.log` 錯誤詳情
2. 檢查後端 API 響應格式
3. 更新 DTO 或 Mapper 層

### Q4: 如何在 Xcode 中運行？

```
1. 打開 Xcode
2. 選擇 Test Navigator (⌘6)
3. 展開 HavitalTests → Integration
4. 右鍵點擊測試類 → Run
```

**注意**: 必須使用 Debug 配置！

## 📚 相關文檔

- [單元測試指南](Testing_Framework_Summary.md)
- [依賴注入指南](Dependency_Injection_Guide.md)
- [架構設計文檔](01-architecture/README.md)
- [快速開始](../Scripts/QUICK_START.md)

## ✅ 成功標準

集成測試通過表示：

1. ✅ **Repository 層正確** - 與真實 API 交互無誤
2. ✅ **UseCase 層正確** - 業務邏輯執行正確
3. ✅ **數據流正確** - 端到端數據傳遞無誤
4. ✅ **重構成功** - Managers → Domain Layer 遷移成功

## 🎯 下一步

1. 為其他 Feature 添加集成測試（Target, User, Workout, etc.）
2. 集成到 CI/CD 流程
3. 設置自動化測試報告
4. 增加性能測試和壓力測試

---

**重要提醒**: 集成測試調用真實 API，請確保：
- ✅ 在開發環境執行
- ✅ 有穩定的網路連接
- ✅ 不要在生產環境運行
- ✅ 測試數據不會影響真實用戶
