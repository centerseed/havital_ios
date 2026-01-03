# Manager 測試框架總結

## 📦 已創建的測試工具

### 1. 測試模板
- **[TrainingPlanManagerTests.swift](../HavitalTests/Managers/TrainingPlanManagerTests.swift)**
  - 完整的單元測試示例
  - Mock 對象實現
  - 測試雙軌緩存、API 調用、錯誤處理、並發、內存洩漏

### 2. 測試腳本
- **[run_tests.sh](../Scripts/run_tests.sh)** - 自動運行測試並生成報告
- **[fix_test_config.sh](../Scripts/fix_test_config.sh)** - 修復 TEST_HOST 配置問題

### 3. 依賴注入指南
- **[Dependency_Injection_Guide.md](Dependency_Injection_Guide.md)**
  - 完整的依賴注入實現指南
  - Protocol 定義示例
  - Mock 對象模板

## 🚀 快速開始

### 運行測試

```bash
cd /Users/wubaizong/havital/apps/ios/Havital

# 運行所有測試
./Scripts/run_tests.sh

# 運行特定測試
./Scripts/run_tests.sh --filter TrainingPlanManagerTests

# 顯示詳細輸出
./Scripts/run_tests.sh -v
```

### 解決配置問題

如果遇到 `Could not find test host` 錯誤：

```bash
# 方法 1: 運行修復腳本
./Scripts/fix_test_config.sh

# 方法 2: 使用依賴注入 (推薦)
# 參考 Docs/Dependency_Injection_Guide.md
```

## ✅ 測試覆蓋範圍

### 已實現的測試

#### TrainingPlanManagerTests
- ✅ `test_loadTrainingOverview_withCache_shouldDisplayCacheImmediately`
  - 驗證有緩存時立即顯示

- ✅ `test_loadTrainingOverview_withCache_shouldRefreshInBackground`
  - 驗證背景刷新邏輯

- ✅ `test_loadTrainingOverview_withoutCache_shouldLoadFromAPI`
  - 驗證無緩存時從 API 載入

- ✅ `test_loadTrainingOverview_whenAPIFails_shouldKeepCache`
  - 驗證 API 失敗時保持緩存

- ✅ `test_loadTrainingOverview_whenAPIFails_withoutCache_shouldShowError`
  - 驗證無緩存時 API 失敗顯示錯誤

- ✅ `test_loadTrainingOverview_whenCancelled_shouldNotUpdateUI`
  - 驗證任務取消處理

- ✅ `test_loadTrainingOverview_multipleCalls_shouldNotDuplicate`
  - 驗證並發請求防重複

- ✅ `test_trainingPlanManager_shouldReleaseAfterTaskCompletion`
  - 驗證無內存洩漏

- ✅ `test_loadWeeklyPlan_withValidWeek_shouldLoadPlan`
  - 驗證週計劃載入

- ✅ `test_loadWeeklyPlan_withoutOverview_shouldLoadOverviewFirst`
  - 驗證依賴載入順序

## 📈 下一步計劃

### 短期目標（1-2 週）

#### 1. 為 TrainingPlanManager 添加依賴注入
- [ ] 創建 `TrainingPlanServiceProtocol`
- [ ] 創建 `TrainingPlanStorageProtocol`
- [ ] 修改 `TrainingPlanManager` 構造函數
- [ ] 運行測試驗證

#### 2. 為其他關鍵 Manager 添加測試
- [ ] UnifiedWorkoutManager
  - [ ] 測試 workout 列表載入
  - [ ] 測試上傳邏輯
  - [ ] 測試背景同步

- [ ] TargetManager
  - [ ] 測試目標載入
  - [ ] 測試目標更新

- [ ] VDOTManager
  - [ ] 測試 VDOT 計算
  - [ ] 測試緩存策略

### 中期目標（1 個月）

#### 3. 集成測試
```swift
// 測試真實 API 調用（使用測試環境）
func test_integration_loadTrainingPlan_shouldWork() async {
    let manager = TrainingPlanManager()
    await manager.loadTrainingOverview()
    XCTAssertNotNil(manager.trainingOverview)
}
```

#### 4. UI 測試
```swift
// 測試完整用戶流程
func test_ui_trainingPlanView_shouldDisplayCorrectly() {
    let app = XCUIApplication()
    app.launch()

    // 等待訓練計劃載入
    let planView = app.otherElements["training_plan_view"]
    XCTAssertTrue(planView.waitForExistence(timeout: 5))
}
```

### 長期目標（2-3 個月）

#### 5. 測試覆蓋率目標
- [ ] Manager 層測試覆蓋率 > 80%
- [ ] Service 層測試覆蓋率 > 70%
- [ ] ViewModel 層測試覆蓋率 > 60%

#### 6. CI/CD 集成
```yaml
# .github/workflows/ios-tests.yml
name: iOS Tests
on: [pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Tests
        run: |
          cd apps/ios/Havital
          ./Scripts/run_tests.sh
```

## 📊 測試指標

### 當前狀態
- ✅ 測試框架: 已建立
- ✅ 測試模板: 1 個 (TrainingPlanManager)
- ⏳ 依賴注入: 需要實現
- ⏳ 覆蓋率: < 10%

### 目標
- 🎯 測試框架: 完整
- 🎯 測試模板: 5+ 個 Manager
- 🎯 依賴注入: 所有 Manager
- 🎯 覆蓋率: > 80%

## 🛠️ 測試最佳實踐

### DO ✅
- ✅ 使用依賴注入讓測試可控
- ✅ 測試邊緣情況（錯誤、取消、超時）
- ✅ 使用 Mock 對象避免真實 API 調用
- ✅ 測試異步邏輯和並發
- ✅ 檢查內存洩漏
- ✅ 保持測試快速（< 1 秒/測試）

### DON'T ❌
- ❌ 依賴真實網路請求
- ❌ 依賴真實數據庫
- ❌ 測試中使用 sleep
- ❌ 忽略測試失敗
- ❌ 測試實現細節而非行為

## 📚 參考資源

- [依賴注入指南](Dependency_Injection_Guide.md)
- [測試示例](../HavitalTests/Managers/TrainingPlanManagerTests.swift)
- [快速開始](../Scripts/QUICK_START.md)
- [架構規範](../CLAUDE.md)

## 🎯 成功標準

### Manager 重構完成標準
1. ✅ 靜態代碼檢查通過
2. ✅ 編譯無錯誤
3. ✅ 單元測試覆蓋率 > 80%
4. ✅ 所有測試通過
5. ✅ 無內存洩漏
6. ✅ 緩存邏輯正確
7. ✅ API 調用可追蹤

### 質量保證流程
```bash
# 重構前
./Scripts/validate_managers.sh --quick

# 重構後
./Scripts/run_tests.sh           # 單元測試
./Scripts/test_with_cache_clear.sh  # 手動驗證
./Scripts/validate_managers.sh   # 完整檢查
```

---

**下一步**: 為 TrainingPlanManager 添加依賴注入，然後運行 `./Scripts/run_tests.sh` 驗證！
