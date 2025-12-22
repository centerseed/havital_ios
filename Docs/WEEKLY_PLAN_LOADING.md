# 週課表載入邏輯文檔

## 📋 文檔概述

本文檔詳細說明 Paceriz iOS App 中週課表（Weekly Plan）的載入邏輯、API 調用機制、緩存策略及優化歷史。

**最後更新**: 2025-10-27
**維護者**: Development Team

---

## 1. 核心概念

### 1.1 週課表（Weekly Plan）

週課表是用戶訓練計畫中每一週的詳細訓練安排，包含：
- 每日訓練項目（TrainingDay）
- 訓練強度、距離、配速等參數
- 課表 ID（格式：`{overview_id}_{week_number}`）

### 1.2 關鍵 API

| API | 方法 | 用途 | 緩存策略 |
|-----|------|------|---------|
| `GET /plan/race_run/status` | `getPlanStatus()` | 獲取訓練計畫狀態 | 8 小時緩存 |
| `GET /plan/race_run/weekly/:id` | `getWeeklyPlanById()` | 獲取指定週課表 | 本地緩存 + skipCache 選項 |
| `POST /plan/race_run/weekly/v2` | `createWeeklyPlan()` | 創建新週課表 | N/A（寫入操作） |

### 1.3 數據流向

```
plan/status API → 判斷狀態 → 決定是否載入課表
                              ↓
                    getWeeklyPlanById() ← 檢查本地緩存
                              ↓
                         更新 UI
```

---

## 2. 緩存機制

### 2.1 雙軌緩存策略

週課表使用**雙軌緩存**策略，平衡即時性與性能：

```swift
// 軌道 A: 立即顯示緩存
if let cachedPlan = TrainingPlanStorage.loadWeeklyPlan(forWeek: week) {
    updateUI(with: cachedPlan)
}

// 軌道 B: 背景更新（可選）
if needsRefresh {
    let freshPlan = try await service.getWeeklyPlanById(planId: id)
    updateUI(with: freshPlan)
    saveToCache(freshPlan)
}
```

### 2.2 緩存存儲

- **位置**: `TrainingPlanStorage.swift`
- **存儲方式**: UserDefaults（JSON 序列化）
- **Key 格式**: `weekly_plan_week_{weekNumber}`
- **緩存內容**: 完整的 `WeeklyPlan` 對象

### 2.3 緩存失效條件

| 條件 | 觸發方式 | 影響 |
|------|---------|------|
| **用戶重新 onboarding** | `CacheEventBus.invalidateCache(for: .trainingPlan)` | 清除所有課表緩存 |
| **手動下拉刷新** | `loadWeeklyPlan(skipCache: true)` | 跳過當前週緩存 |
| **切換到其他週** | `fetchWeekPlan(week:)` | 跳過指定週緩存 |
| **用戶登出** | `CacheEventBus.invalidateCache(for: .userLogout)` | 清除所有緩存 |

---

## 3. 週課表載入場景

### 3.1 必要的載入場景

#### 場景 1: App 初始化
**觸發位置**: `TrainingPlanViewModel.performUnifiedInitialization()`
**調用路徑**:
```
loadPlanStatus(skipCache: true)
  ↓
handlePlanStatusAction()
  ↓ (如果 nextAction == .viewPlan)
loadWeeklyPlan()
```

**邏輯**:
1. 調用 plan/status API 獲取當前狀態
2. 根據 `nextAction` 決定下一步：
   - `viewPlan`: 載入並顯示課表
   - `createSummary`: 顯示「產生週回顧」按鈕
   - `createPlan`: 顯示「產生課表」按鈕
   - `trainingCompleted`: 顯示訓練完成提示

**代碼位置**: [TrainingPlanViewModel.swift:493-495](../Havital/ViewModels/TrainingPlanViewModel.swift#L493-L495)

---

#### 場景 2: 用戶手動切換週
**觸發位置**: `WeekSelectorSheet` → `fetchWeekPlan(week:)`
**調用路徑**:
```
用戶點擊週選擇器
  ↓
fetchWeekPlan(week: Int)
  ↓
loadWeeklyPlan(skipCache: true, targetWeek: week)
```

**特點**:
- 總是跳過緩存（`skipCache: true`）
- 更新 `selectedWeek` 狀態
- 重新加載該週的 workout 記錄

**代碼位置**: [TrainingPlanViewModel.swift:1193-1205](../Havital/ViewModels/TrainingPlanViewModel.swift#L1193-L1205)

---

#### 場景 3: 用戶手動下拉刷新
**觸發位置**: `TrainingPlanView` → `.refreshable`
**調用路徑**:
```
用戶下拉刷新
  ↓
refreshWeeklyPlan(isManualRefresh: true)
  ↓
loadPlanStatus(skipCache: true)  // 重新檢查狀態
  ↓
loadWeeklyPlan(skipCache: true)  // 強制刷新課表
```

**特點**:
- 同時刷新 plan status 和週課表
- 跳過所有緩存
- 同步更新 workout 數據

**代碼位置**: [TrainingPlanViewModel.swift:1413-1427](../Havital/ViewModels/TrainingPlanViewModel.swift#L1413-L1427)

---

#### 場景 4: 生成新週課表後
**觸發位置**: `GenerateNextWeekButton` → `performGenerateNextWeekPlan()`
**調用路徑**:
```
生成新週課表 API
  ↓
updateWeeklyPlanUI(plan: newPlan)  // 更新 UI 和 weekDateInfo
  ↓
loadWorkoutsForCurrentWeek()       // 重新加載 workout
  ↓
loadPlanStatus(skipCache: true)    // 驗證狀態
```

**特點**:
- 使用 `updateWeeklyPlanUI()` 確保 `weekDateInfo` 正確更新
- 立即重新加載 workout 記錄（避免顯示舊週數據）
- 驗證新狀態

**代碼位置**: [TrainingPlanViewModel.swift:2347-2403](../Havital/ViewModels/TrainingPlanViewModel.swift#L2347-L2403)

---

#### 場景 5: App 從後台回到前台
**觸發位置**: `TrainingPlanView` → `UIApplication.willEnterForegroundNotification`
**調用路徑**:
```
App 回到前台
  ↓
refreshWorkouts()
  ↓
loadPlanStatus()                    // 檢查狀態（8 小時緩存）
  ↓
refreshWeeklyPlan()                 // 刷新課表
  ↓ (內部調用)
loadWeeklyPlan(skipCache: true)
```

**特點**:
- `loadPlanStatus()` 使用 8 小時緩存機制
- `refreshWeeklyPlan()` 內部已調用 `loadWeeklyPlan(skipCache: true)`
- ✅ **已優化**: 移除重複的 `loadWeeklyPlan()` 調用

**代碼位置**: [TrainingPlanView.swift:623-638](../Havital/Views/Training/TrainingPlanView.swift#L623-L638)

---

#### 場景 6: 錯誤重試
**觸發位置**: `ErrorView` 重試按鈕
**調用路徑**:
```
用戶點擊重試
  ↓
loadWeeklyPlan()
```

**特點**:
- 不跳過緩存（除非之前因為緩存過期）
- 重新嘗試 API 調用

**代碼位置**: [TrainingPlanView.swift:457](../Havital/Views/Training/TrainingPlanView.swift#L457)

---

### 3.2 已移除的不必要載入場景

#### ❌ 已移除：TrainingOverviewUpdated 後自動載入

**移除原因**:
1. Overview 更新只影響元數據（如 `totalWeeks`、`createdAt`），不影響週課表內容
2. 週課表由獨立的 API 管理，overview 變更不代表課表變更
3. 如果需要新課表，plan/status API 會告知

**移除日期**: 2025-10-27
**代碼位置**: [TrainingPlanViewModel.swift:629-631](../Havital/ViewModels/TrainingPlanViewModel.swift#L629-L631)

**移除前**:
```swift
NotificationCenter.default.publisher(for: "TrainingOverviewUpdated")
    .sink { notification in
        // ...
        await self.loadWeeklyPlan()  // ❌ 不必要
    }
```

**移除後**:
```swift
NotificationCenter.default.publisher(for: "TrainingOverviewUpdated")
    .sink { notification in
        // ✅ 只重新載入相關數據，不載入課表
        await self.loadCurrentWeekDistance()
        await self.loadCurrentWeekIntensity()
        await self.loadWorkoutsForCurrentWeek()
    }
```

---

#### ❌ 已移除：refreshWorkouts() 中的重複調用

**移除原因**:
`refreshWeeklyPlan()` 內部已經調用了 `loadWeeklyPlan(skipCache: true)`，不需要再次檢查 `weeklyPlan == nil` 並載入。

**移除日期**: 2025-10-27
**代碼位置**: [TrainingPlanView.swift:632-635](../Havital/Views/Training/TrainingPlanView.swift#L632-L635)

**移除前**:
```swift
await viewModel.refreshWeeklyPlan()  // 已調用 loadWeeklyPlan(skipCache: true)

if viewModel.weeklyPlan == nil {
    await viewModel.loadWeeklyPlan()  // ❌ 重複調用
}
```

**移除後**:
```swift
await viewModel.refreshWeeklyPlan()  // 內部已處理

// ✅ 移除重複調用
```

---

## 4. 與 plan/status API 的配合

### 4.1 plan/status API 緩存機制

**緩存時間**: 8 小時
**緩存邏輯**:
```swift
func loadPlanStatus(skipCache: Bool = false) async {
    if !skipCache, let lastFetchTime = lastPlanStatusFetchTime {
        let timeSinceLastFetch = Date().timeIntervalSince(lastFetchTime)
        if timeSinceLastFetch < planStatusCacheInterval {
            // 8 小時內，使用緩存
            return
        }
    }

    // 調用 API
    let status = try await TrainingPlanService.shared.getPlanStatus()
    self.lastPlanStatusFetchTime = Date()
}
```

### 4.2 調用時機

| 場景 | skipCache 參數 | 行為 |
|------|---------------|------|
| App 初始化 | `true` | 跳過緩存，獲取最新狀態 |
| 手動下拉刷新 | `true` | 跳過緩存，強制刷新 |
| 生成新週課表後 | `true` | 跳過緩存，同步新狀態 |
| App 回到前台 | `false` | 使用緩存（8 小時內） |

### 4.3 plan/status 返回的課表資訊

```swift
struct PlanStatusResponse {
    let currentWeek: Int
    let totalWeeks: Int
    let currentWeekPlanId: String?       // 當前週課表 ID
    let nextAction: NextAction           // 前端應執行的下一步操作
    let nextWeekInfo: NextWeekInfo?      // 下週課表資訊
}
```

**使用方式**:
- `currentWeekPlanId`: 可用於檢查緩存 ID 是否一致（未來優化點）
- `nextAction`: 決定 UI 顯示內容

---

## 5. 核心函數說明

### 5.1 loadWeeklyPlan()

**位置**: [TrainingPlanViewModel.swift:930-1150](../Havital/ViewModels/TrainingPlanViewModel.swift#L930-L1150)

**簽名**:
```swift
func loadWeeklyPlan(skipCache: Bool = false, targetWeek: Int? = nil) async
```

**參數**:
- `skipCache`: 是否跳過本地緩存
- `targetWeek`: 指定要載入的週數（nil 則使用 `selectedWeek`）

**邏輯流程**:
1. 檢查緩存（如果 `skipCache == false`）
2. 如果有緩存，立即更新 UI
3. 調用 API 獲取最新課表
4. 更新 UI 並保存到緩存

**錯誤處理**:
- `WeeklyPlanError.notFound`: 設置 `planStatus = .noPlan`
- 其他錯誤: 設置 `planStatus = .error(error)`

---

### 5.2 handlePlanStatusAction()

**位置**: [TrainingPlanViewModel.swift:483-528](../Havital/ViewModels/TrainingPlanViewModel.swift#L483-L528)

**職責**: 根據 plan/status API 返回的 `nextAction` 決定下一步操作

**邏輯**:
```swift
switch status.nextAction {
case .viewPlan:
    // 載入並顯示課表
    await loadWeeklyPlan()

case .createSummary, .createPlan:
    // 檢查緩存，如果有則顯示，否則顯示產生按鈕
    if let cachedPlan = TrainingPlanStorage.loadWeeklyPlan(forWeek: currentWeek) {
        await updateWeeklyPlanUI(plan: cachedPlan, status: .ready(cachedPlan))
    } else {
        await updateWeeklyPlanUI(plan: nil, status: .noPlan)
    }

case .trainingCompleted:
    // 顯示訓練完成提示
    await updateWeeklyPlanUI(plan: nil, status: .completed)

case .noActivePlan:
    // 無活躍訓練計畫
    await updateWeeklyPlanUI(plan: nil, status: .noPlan)
}
```

---

### 5.3 refreshWeeklyPlan()

**位置**: [TrainingPlanViewModel.swift:1413-1427](../Havital/ViewModels/TrainingPlanViewModel.swift#L1413-L1427)

**職責**: 手動刷新週課表和相關數據

**邏輯**:
```swift
func refreshWeeklyPlan(isManualRefresh: Bool = false) async {
    // 手動刷新時，重新檢查 plan status
    if isManualRefresh {
        await loadPlanStatus(skipCache: true)
    }

    // 刷新週課表（跳過緩存）
    await loadWeeklyPlan(skipCache: true)

    // 刷新 workout 數據
    await unifiedWorkoutManager.refreshWorkouts()

    // 重新載入當前週數據
    await loadCurrentWeekData()
}
```

---

## 6. 優化歷史

### 6.1 2025-10-27: 移除冗餘的 API 調用

**問題**:
1. `refreshWorkouts()` 中存在重複的 `loadWeeklyPlan()` 調用
2. `TrainingOverviewUpdated` notification 觸發不必要的課表載入

**修復**:
- ✅ 移除 `refreshWorkouts()` 中的條件檢查和重複調用
- ✅ 移除 `TrainingOverviewUpdated` 後的自動課表載入

**效果**:
- App 回到前台: 減少最多 1 次 API 調用
- 更新 overview: 減少 1 次 API 調用

---

### 6.2 2025-10-27: 實現 plan/status API 8 小時緩存

**問題**:
App 每次回到前台都會調用 plan/status API，即使狀態未變

**修復**:
- ✅ 添加 `lastPlanStatusFetchTime` 時間戳
- ✅ 實現 8 小時緩存機制
- ✅ 手動刷新時跳過緩存

**效果**:
- 常規場景（8 小時內）: 減少 100% plan/status API 調用

---

### 6.3 2025-10-27: 修復生成新週課表後 workout 記錄殘留

**問題**:
生成新週課表後，主畫面顯示下週課表，但舊週的 workout 記錄仍然顯示

**根本原因**:
1. `performGenerateNextWeekPlan()` 直接更新 UI，未更新 `weekDateInfo`
2. `getCurrentWeekDates()` 使用過時的日期範圍
3. 沒有重新加載 workout 記錄

**修復**:
- ✅ 使用 `updateWeeklyPlanUI()` 確保 `weekDateInfo` 正確更新
- ✅ 添加 `loadWorkoutsForCurrentWeek()` 調用
- ✅ 添加詳細日誌用於調試

**代碼位置**: [TrainingPlanViewModel.swift:2315, 2339](../Havital/ViewModels/TrainingPlanViewModel.swift#L2315)

---

## 7. 未來優化建議

### 7.1 利用 currentWeekPlanId 減少 API 調用

**當前問題**:
即使課表未變，`nextAction == .viewPlan` 時仍會調用 API

**優化方案**:
```swift
case .viewPlan:
    // 檢查緩存中的課表 ID 是否與 status 返回的一致
    if let cachedPlan = TrainingPlanStorage.loadWeeklyPlan(forWeek: status.currentWeek),
       let currentPlanId = status.currentWeekPlanId,
       cachedPlan.id == currentPlanId {
        // ID 一致，使用緩存
        await updateWeeklyPlanUI(plan: cachedPlan, status: .ready(cachedPlan))
        return
    }

    // ID 不一致或無緩存，調用 API
    await loadWeeklyPlan()
```

**預期效果**:
- 常規場景（課表未變）: 減少 100% weekly plan API 調用

**風險**:
- ⚠️ 需要確保後端 ID 生成邏輯穩定
- ⚠️ 需要充分測試各種邊緣情況

---

### 7.2 實現週課表的版本控制

**概念**:
為每個週課表添加版本號或 `updatedAt` 時間戳

**優勢**:
- 可以更精確地判斷緩存是否過期
- 支持部分更新（只更新變更的部分）

**實現建議**:
需要後端 API 支持返回版本資訊

---

## 8. 注意事項與最佳實踐

### 8.1 課表只有 App 可以修改

**重要**: 週課表只能由 App 前端修改，後端不會單獨更新課表內容

**影響**:
- 不需要頻繁輪詢課表變更
- 可以更激進地使用緩存
- 只在用戶操作（編輯、生成新週）後才需要刷新

---

### 8.2 避免在初始化時重複載入

**錯誤示範**:
```swift
init() {
    Task {
        await loadWeeklyPlan()  // ❌ 會被自動初始化流程重複調用
    }
}
```

**正確做法**:
依賴 `performUnifiedInitialization()` 的統一初始化流程

---

### 8.3 總是使用 updateWeeklyPlanUI() 更新 UI

**原因**:
`updateWeeklyPlanUI()` 會同步更新：
- `weeklyPlan`
- `weekDateInfo`（週日期範圍資訊）
- `currentPlanWeek`
- `selectedWeek`
- `planStatus`

**錯誤示範**:
```swift
self.weeklyPlan = newPlan  // ❌ weekDateInfo 未更新
```

**正確做法**:
```swift
await updateWeeklyPlanUI(plan: newPlan, status: .ready(newPlan))  // ✅
```

---

### 8.4 處理任務取消

**重要**: 所有 async 操作都應該處理 `CancellationError`

**正確做法**:
```swift
} catch {
    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
        Logger.debug("任務被取消，忽略錯誤")
        return  // 不更新 UI 狀態
    }

    // 處理真實錯誤
    await updateUI(error: error)
}
```

---

## 9. 相關文件

- [CLAUDE.md](../CLAUDE.md) - 專案架構原則與任務管理
- [ARCHITECTURE.md](ARCHITECTURE.md) - 完整架構文檔
- [UNIFIED_ARCHITECTURE_GUIDE.md](UNIFIED_ARCHITECTURE_GUIDE.md) - 統一架構指南
- [data_flow_architecture.md](data_flow_architecture.md) - 數據流架構

---

## 10. 變更記錄

| 日期 | 變更內容 | 負責人 |
|------|---------|--------|
| 2025-10-27 | 初始版本，記錄週課表載入邏輯 | Development Team |
| 2025-10-27 | 優化 API 調用，移除冗餘載入 | Development Team |
| 2025-10-27 | 實現 plan/status 8 小時緩存 | Development Team |

---

## 附錄：快速參考

### 常見問題

**Q: 用戶手動刷新會調用多少次 API？**
A: 2 次（plan/status + weekly plan），都會跳過緩存

**Q: App 回到前台會調用多少次 API？**
A: 最多 1 次（如果 plan/status 緩存已過期），weekly plan 可能使用緩存

**Q: 生成新週課表後會調用多少次 API？**
A: 2 次（createWeeklyPlan + loadPlanStatus 驗證）

**Q: 如何強制刷新課表？**
A: 調用 `loadWeeklyPlan(skipCache: true)`

**Q: 緩存會自動過期嗎？**
A: 不會，只有在特定條件下才會失效（見 2.3 節）
