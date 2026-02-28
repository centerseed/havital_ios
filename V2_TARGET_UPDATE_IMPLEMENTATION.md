# V2 調整目標賽事後重新更新 Plan Overview - 實作總結

## 實作狀態: ✅ 完成

實作日期: 2026-02-17

---

## 📋 實作內容

### Phase 1: TrainingPlanV2ViewModel 新增 updateOverview 方法 ✅

**檔案**: `TrainingPlanV2ViewModel.swift` (Line 908-981)

**新增方法**:
```swift
/// 更新訓練計畫概覽（當賽事目標有重要變更時）
func updateOverview() async
```

**功能**:
- 驗證 `overviewId` 存在
- 顯示全屏 loading 動畫
- 調用 `repository.updateOverview(overviewId:startFromStage:)`
- 更新成功後:
  - 更新 `planOverview`
  - 顯示成功 toast 訊息
  - 清除所有快取
  - 重新載入 Plan Status
- 錯誤處理:
  - 處理 `CancellationError`
  - 處理 `NSURLErrorCancelled`
  - 其他錯誤顯示在 `networkError`

---

### Phase 2: PlanOverviewSheetV2 監聽通知並觸發更新 ✅

**檔案**: `PlanOverviewSheetV2.swift` (Line 75-99)

**新增功能**:
```swift
.onReceive(NotificationCenter.default.publisher(for: .targetUpdated)) { notification in
    // 檢查是否有重要變更
    if let hasSignificantChange = userInfo["hasSignificantChange"] as? Bool,
       hasSignificantChange {
        // 觸發 updateOverview()
    } else {
        // 僅重新載入賽事資料
    }
}
```

**流程**:
1. 監聽 `.targetUpdated` 通知
2. 檢查 `hasSignificantChange` userInfo
3. 如果有重要變更:
   - 關閉編輯 sheet
   - 重新載入賽事資料 (`targetViewModel.forceRefresh()`)
   - 觸發訓練計劃概覽更新 (`viewModel.updateOverview()`)
4. 如果無重要變更:
   - 僅重新載入賽事資料

---

### Phase 3: (跳過) 使用 CacheEventBus ⏭️

**原因**:
- V1 已使用 `NotificationCenter.default.post(name: .targetUpdated)`
- 為保持相容性,V2 直接使用相同的通知機制
- 未來可選擇性重構為 CacheEventBus

---

## 🔍 依賴關係

### 已存在的基礎設施 ✅

1. **Backend API**: `PUT /training_plan/overview/{overview_id}`
   - 定義在 `TrainingPlanV2Repository.swift:63`
   - 實作在 `TrainingPlanV2RepositoryImpl.swift`

2. **EditTargetView 通知機制**:
   - 位置: `EditTargetView.swift:88-92`
   - 發送 `.targetUpdated` 通知,附帶 `hasSignificantChange`

3. **EditTargetViewModel 變更檢測**:
   - 位置: `EditTargetView.swift:225-227`
   - 正確判斷距離、完賽時間、訓練週數的變更

4. **本地化字串**:
   - Key: `training.plan_regenerated`
   - 內容: "訓練計畫已根據最新目標重新產生"
   - 位置: `zh-Hant.lproj/Localizable.strings:735`

5. **Notification.Name extension**:
   - `.targetUpdated` 定義在 `TargetStorage.swift:186`

---

## ✅ 驗證方式

### 1. Build 測試
```bash
xcodebuild build -project Havital.xcodeproj -scheme Havital -destination 'generic/platform=iOS Simulator'
```
**結果**: ✅ BUILD SUCCEEDED

### 2. 功能測試步驟

#### 前置準備
- 確保有 active 訓練計劃（已完成 onboarding）
- 進入 TrainingPlanV2View
- 點擊 PlanOverviewSheetV2

#### 測試場景 1: 編輯賽事（無重要變更）
1. 點擊「編輯主要賽事」
2. 只修改賽事名稱
3. 點擊「儲存」

**預期結果**:
- ✅ Sheet 關閉
- ✅ 賽事資料重新載入
- ❌ **不應觸發** overview 更新
- ❌ **不應顯示** loading 動畫
- ❌ **不應顯示** "訓練計劃已重新產生" toast

#### 測試場景 2: 編輯賽事（有重要變更 - 距離）
1. 點擊「編輯主要賽事」
2. 修改賽事距離（如 半馬 → 全馬）
3. 點擊「儲存」

**預期結果**:
- ✅ Sheet 關閉
- ✅ 賽事資料重新載入
- ✅ 顯示全屏 loading 動畫
- ✅ 調用 `PUT /training_plan/overview/{overview_id}` API
- ✅ 成功後顯示 toast: "訓練計劃已根據最新目標重新產生"
- ✅ Overview 資料已更新（總週數、目標距離等）
- ✅ 週課表快取已清除並重新載入

#### 測試場景 3: 編輯賽事（有重要變更 - 完賽時間）
1. 點擊「編輯主要賽事」
2. 修改目標完賽時間（如 4小時 → 3小時30分）
3. 點擊「儲存」

**預期結果**:
- ✅ 同場景 2

#### 測試場景 4: 編輯賽事（有重要變更 - 訓練週數）
1. 點擊「編輯主要賽事」
2. 修改賽事日期（影響訓練週數）
3. 點擊「儲存」

**預期結果**:
- ✅ 同場景 2

#### 測試場景 5: 錯誤處理
1. 斷開網路
2. 修改賽事距離
3. 點擊「儲存」

**預期結果**:
- ✅ 顯示 loading 動畫
- ✅ API 調用失敗
- ✅ Loading 動畫消失
- ✅ 顯示錯誤 toast
- ✅ Overview 保持舊資料（不變）

---

## 🔄 資料流

```
使用者修改賽事 (EditTargetView)
  ↓
EditTargetViewModel.updateTarget()
  ↓
判斷 hasSignificantChange
  ↓
發送 NotificationCenter.post(.targetUpdated, userInfo: ["hasSignificantChange": true])
  ↓
PlanOverviewSheetV2.onReceive(.targetUpdated)
  ↓
檢查 hasSignificantChange == true
  ↓
Task {
  1. showEditMainTarget = false
  2. await targetViewModel.forceRefresh()
  3. await viewModel.updateOverview()
}
  ↓
TrainingPlanV2ViewModel.updateOverview()
  ↓
1. 顯示 loading (isLoadingAnimation = true)
2. 調用 repository.updateOverview(overviewId, startFromStage: nil)
3. 更新 planOverview
4. 顯示 successToast
5. 清除快取 (repository.clearCache())
6. 重新載入狀態 (loadPlanStatus())
  ↓
UI 更新完成
```

---

## 📝 程式碼檢查清單

- [x] TrainingPlanV2ViewModel 有 `updateOverview()` 方法
- [x] PlanOverviewSheetV2 監聽 `.targetUpdated` 通知
- [x] 有重要變更時觸發 `viewModel.updateOverview()`
- [x] Loading 動畫正確顯示和隱藏 (`isLoadingAnimation`)
- [x] 成功後顯示 toast 訊息 (`successToast`)
- [x] 錯誤處理正確 (顯示 `networkError`)
- [x] `CancellationError` 被正確過濾
- [x] `NSURLErrorCancelled` 被正確過濾
- [x] Build 通過: ✅ BUILD SUCCEEDED
- [x] 清除快取並重新載入 Plan Status
- [x] 日誌記錄完整 (Logger.debug/info/error)

---

## 🎯 與 V1 的對比

| 功能 | V1 實現 | V2 實現 | 狀態 |
|------|---------|---------|------|
| 判斷重要變更 | ✅ EditTargetViewModel | ✅ EditTargetViewModel (共用) | ✅ 完成 |
| 發送通知 | ✅ NotificationCenter | ✅ NotificationCenter (共用) | ✅ 完成 |
| 監聽通知 | ✅ TrainingPlanOverviewDetailView | ✅ PlanOverviewSheetV2 | ✅ 完成 |
| 更新 Overview | ✅ TrainingPlanViewModel.updateOverview() | ✅ TrainingPlanV2ViewModel.updateOverview() | ✅ 完成 |
| Loading 狀態 | ✅ isUpdatingOverview | ✅ isLoadingAnimation | ✅ 完成 |
| 成功提示 | ✅ 自訂 overlay | ✅ successToast | ✅ 完成 |
| 錯誤處理 | ✅ showUpdateStatus | ✅ networkError toast | ✅ 完成 |

---

## 🚀 下一步 (可選)

### 未來優化建議

1. **Phase 3 實作**: 使用 CacheEventBus 代替 NotificationCenter
   - 定義事件: `.targetUpdatedWithSignificantChange`
   - 修改 EditTargetView 發送 CacheEventBus 事件
   - 修改 PlanOverviewSheetV2 訂閱 CacheEventBus
   - 好處: 符合 Clean Architecture，避免直接依賴 NotificationCenter

2. **單元測試**:
   - 測試 `updateOverview()` 方法的各種場景
   - Mock Repository 驗證 API 調用
   - 驗證狀態轉換正確性

3. **UI 優化**:
   - 考慮添加「更新中...」的進度提示
   - 優化 loading 動畫過渡效果

---

## 📚 相關文件

- **架構設計**: `Docs/01-architecture/ARCH-002-Clean-Architecture-Design.md`
- **V1 實作參考**: `Havital/Features/TrainingPlan/Presentation/ViewModels/TrainingPlanViewModel.swift`
- **計劃文檔**: 用戶提供的實作計劃

---

## ✅ 總結

本次實作成功將 V1 的「賽事編輯後自動重新產生訓練計劃」功能移植到 V2,並保持了與 V1 相同的使用者體驗:

1. ✅ **自動判斷**: 只有距離、完賽時間、訓練週數變更時才重新產生
2. ✅ **無縫體驗**: 自動關閉編輯 sheet,顯示 loading,更新完成後顯示成功訊息
3. ✅ **錯誤處理**: 正確處理網路錯誤、取消操作
4. ✅ **Clean Architecture**: 遵循依賴反轉原則,ViewModel 依賴 Repository Protocol
5. ✅ **程式碼品質**: 完整的日誌記錄,清晰的錯誤處理

**實作完成度**: 100%
**Build 狀態**: ✅ SUCCEEDED
**待驗證**: 需要實機測試確認 UI 流程
