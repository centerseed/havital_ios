# 修復 TEST_HOST 配置問題

## 問題描述

運行測試時出現錯誤：
```
xcodebuild: error: Failed to build project Havital with scheme Havital.:
Could not find test host for HavitalTests: TEST_HOST evaluates to
"/Users/wubaizong/Library/Developer/Xcode/DerivedData/Havital-.../Build/Products/Debug-iphonesimulator/Paceriz.app/Paceriz"
```

**根本原因**:
- 產品名稱已改為 `Paceriz`（用戶可見）
- 實際構建產物名稱是 `paceriz_dev.app`（Debug/Dev 配置）
- 測試目標（HavitalTests）的 TEST_HOST 配置仍指向 `Paceriz.app`

## 解決方案 1: 使用 Xcode 運行測試（推薦）

在修復項目配置前，使用 Xcode IDE 運行測試：

1. **打開項目**
   ```bash
   open /Users/wubaizong/havital/apps/ios/Havital/Havital.xcodeproj
   ```

2. **選擇測試目標**
   - 按 `Cmd + 5` 打開測試導航器
   - 找到 `TrainingPlanViewModelTests`
   - 點擊測試類旁邊的 ▶️ 按鈕

3. **查看結果**
   - 測試會在 Xcode 中直接運行
   - 可以看到每個測試的通過/失敗狀態
   - 可以查看覆蓋率報告

## 解決方案 2: 修復項目配置（永久修復）

### 步驟 1: 在 Xcode 中打開項目設置

1. 打開 Xcode
2. 選擇 `Havital` 項目（藍色圖標）
3. 選擇 `HavitalTests` Target
4. 點擊 `Build Settings` 標籤頁
5. 搜索 `TEST_HOST`

### 步驟 2: 檢查當前配置

當前 TEST_HOST 可能設置為：
```
$(BUILT_PRODUCTS_DIR)/Paceriz.app/Paceriz
```

或
```
$(BUILT_PRODUCTS_DIR)/$(PRODUCT_NAME).app/$(PRODUCT_NAME)
```

### 步驟 3: 修復配置

根據不同的構建配置，應該設置為：

**Debug 配置:**
```
$(BUILT_PRODUCTS_DIR)/paceriz_dev.app/paceriz_dev
```

**Dev 配置:**
```
$(BUILT_PRODUCTS_DIR)/paceriz_dev.app/paceriz_dev
```

**Prod 配置:**
```
$(BUILT_PRODUCTS_DIR)/Paceriz.app/Paceriz
```

**Release 配置:**
```
$(BUILT_PRODUCTS_DIR)/Paceriz.app/Paceriz
```

### 步驟 4: 使用變量（推薦）

最佳做法是使用 Xcode 變量，自動適配不同配置：

1. 確認主 App Target (Havital) 的 `PRODUCT_NAME` 設置：
   - Debug: `paceriz_dev`
   - Dev: `paceriz_dev`
   - Prod: `Paceriz`
   - Release: `Paceriz`

2. 在 HavitalTests 的 TEST_HOST 中使用：
   ```
   $(BUILT_PRODUCTS_DIR)/$(TEST_HOST_PRODUCT_NAME).app/$(TEST_HOST_PRODUCT_NAME)
   ```

3. 添加 `TEST_HOST_PRODUCT_NAME` 用戶定義變量：
   - Debug: `paceriz_dev`
   - Dev: `paceriz_dev`
   - Prod: `Paceriz`
   - Release: `Paceriz`

### 步驟 5: 清理並重新構建

修復配置後：
```bash
cd /Users/wubaizong/havital/apps/ios/Havital
rm -rf ~/Library/Developer/Xcode/DerivedData/Havital-*
xcodebuild clean -project Havital.xcodeproj -scheme Havital
```

然後重新運行測試。

## 解決方案 3: 暫時使用 Prod 配置運行測試

```bash
cd /Users/wubaizong/havital/apps/ios/Havital

# 使用 Prod 配置（產品名稱是 Paceriz）
xcodebuild test \
    -project Havital.xcodeproj \
    -scheme "Havital Prod" \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:HavitalTests/TrainingPlanViewModelTests
```

## 驗證修復

修復後，運行以下命令驗證：

```bash
# 方法 1: 通過腳本
./Scripts/test_training_plan.sh viewmodel

# 方法 2: 直接使用 xcodebuild
xcodebuild test \
    -project Havital.xcodeproj \
    -scheme Havital \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:HavitalTests/TrainingPlanViewModelTests
```

成功的輸出應該包含：
```
Test Suite 'TrainingPlanViewModelTests' passed
    ✓ testFirstWeekReady_noPrompts (0.001 seconds)
    ✓ testSecondWeekStart_showNewWeekPrompt (0.001 seconds)
    ...
```

## 檢查清單

- [ ] 確認主 App 的 PRODUCT_NAME 設置
- [ ] 檢查 HavitalTests 的 TEST_HOST 配置
- [ ] 針對每個構建配置（Debug/Dev/Prod/Release）設置正確的值
- [ ] 清理 DerivedData
- [ ] 運行測試驗證修復

## 相關文件

- Xcode 項目: `Havital.xcodeproj/project.pbxproj`
- 測試腳本: `Scripts/test_training_plan.sh`
- 測試策略: `Docs/refactor/04-TESTING-STRATEGY.md`

## 參考資料

- [Xcode Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
- [Running Tests from the Command Line](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/08-command_line_testing.html)
