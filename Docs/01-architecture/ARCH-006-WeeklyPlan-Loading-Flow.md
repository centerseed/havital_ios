# 週課表載入流程完整說明

> 最後更新：2026-01-26

本文件詳細描述週課表在各種情境下的載入機制，包括 App 啟動、背景恢復、跨週處理、週數切換、產生課表等。

---

## ⚠️ 問題修復摘要

| 優先級 | 問題 | 影響 | 狀態 |
|--------|------|------|------|
| ✅ 已修復 | weekChanged 事件未更新 planStatus | 跨週後 UI 卡在舊狀態 | 已修復 |
| ✅ 已修復 | dataChanged.trainingPlan 事件未更新 planStatus | 修改課表後 UI 未更新 | 已修復 |
| ✅ 已修復 | targetUpdated 事件未更新 planStatus | 更新目標後 UI 未更新 | 已修復 |
| ✅ 已修復 | generateNextWeekPlan 產生課表後顯示舊課表 | 需滑掉 App 才顯示新課表 | 已修復 |
| ⚠️ 中 | refreshPlanStatus 缺少 Fallback | API 失敗時無法顯示舊緩存 | 待處理 |
| ⚠️ 低 | 未跨週時不刷新 planStatus | 長時間後狀態可能過時 | 設計如此 |

---

## 目錄

1. [核心概念](#一核心概念)
2. [UI 狀態定義](#二ui-狀態定義)
3. [關鍵 API 與緩存設定](#三關鍵-api-與緩存設定)
4. [App 啟動流程（乾淨啟動）](#四app-啟動流程乾淨啟動)
5. [App 背景恢復流程](#五app-背景恢復流程)
6. [跨週檢測機制](#六跨週檢測機制)
7. [週數切換機制](#七週數切換機制)
8. [產生下週課表機制](#八產生下週課表機制)
9. [情境矩陣分析](#九情境矩陣分析)
10. [緩存策略詳解](#十緩存策略詳解)
11. [事件驅動更新機制](#十一事件驅動更新機制)
12. [代碼實現參考](#十二代碼實現參考)
13. [流程圖](#十三流程圖)
14. [關鍵修復說明](#十四關鍵修復說明)

---

## 一、核心概念

### 1.1 關鍵變數

| 變數名稱 | 說明 | 來源 | 更新時機 |
|----------|------|------|----------|
| `currentWeek` | 後端計算的當前訓練週數 | Plan Status API | 每次呼叫 loadPlanStatus |
| `selectedWeek` | 用戶當前查看的週數 | ViewModel 本地狀態 | 用戶切換週數或初始化時重置 |
| `planStatus` | UI 狀態（loading/noPlan/ready/completed/error） | ViewModel | 根據數據載入結果更新 |
| `planStatusResponse` | Plan Status API 完整回應 | Repository | 每次呼叫 loadPlanStatus |
| `lastActiveMonday` | 上次 App 活躍時的日曆週一 | AppViewModel 本地狀態 | App 啟動/恢復時更新 |

### 1.2 NextAction 列舉

Plan Status API 返回的 `nextAction` 決定 UI 應該顯示什麼：

| NextAction | 說明 | planStatus 應設為 | UI 行為 |
|------------|------|-------------------|---------|
| `viewPlan` | 當週課表已存在 | `.ready(plan)` | 載入並顯示週課表 |
| `createSummary` | 需先產生上週回顧 | `.noPlan` | 顯示「產生週回顧」按鈕 |
| `createPlan` | 可直接產生當週課表 | `.noPlan` | 顯示「產生課表」按鈕 |
| `trainingCompleted` | 訓練計畫已完成 | `.completed` | 顯示完成提示畫面 |
| `noActivePlan` | 無啟動中的訓練計畫 | `.noPlan` | 顯示無計畫狀態 |

### 1.3 時區處理

所有跨週判斷都基於**用戶本地時區**：
- 週日 23:59:59 → 週一 00:00:00 即為跨週
- 使用 `TimeZone.current` 確保時區正確

---

## 二、UI 狀態定義

### 2.1 PlanStatus 列舉

```swift
enum PlanStatus {
    case loading          // 正在載入
    case noPlan           // 顯示「產生週回顧」或「產生課表」按鈕
    case ready(WeeklyPlan) // 顯示課表內容
    case completed        // 訓練計畫已完成
    case error(Error)     // 顯示錯誤視圖
}
```

### 2.2 UI 元件對應表

| PlanStatus | 主要顯示內容 | 觸發條件 |
|------------|-------------|----------|
| `.loading` | 載入動畫（半透明覆蓋） | 初始化、切換週數、刷新時 |
| `.noPlan` | `NewWeekPromptView`（產生週回顧按鈕） | `nextAction` = createSummary/createPlan/noActivePlan |
| `.ready(plan)` | 訓練進度卡 + 週總覽 + 時間軸 | `nextAction` = viewPlan 且課表載入成功 |
| `.completed` | `FinalWeekPromptView`（訓練完成提示） | `nextAction` = trainingCompleted |
| `.error(error)` | `ErrorView`（重試按鈕） | API 錯誤且無緩存 |

### 2.3 附加 UI 元件

| 元件 | 顯示條件 | 位置 |
|------|----------|------|
| `ReturnToCurrentWeekButton` | `selectedWeek > currentWeek` | 主內容上方 |
| `GenerateNextWeekButton` | `nextWeekInfo.canGenerate && !nextWeekInfo.hasPlan && selectedWeek == currentWeek` | 主內容下方 |
| 成功 Toast | `successToast != nil` | 頂部覆蓋 |
| 網路錯誤 Toast | `showNetworkErrorToast` | 頂部覆蓋 |

---

## 三、關鍵 API 與緩存設定

### 3.1 API 端點

| API | 用途 | 關鍵回傳欄位 |
|-----|------|--------------|
| `GET /plan/race_run/status` | 取得計畫狀態 | `current_week`, `next_action`, `current_week_plan_id`, `can_generate_next_week`, `next_week_info` |
| `GET /plan/race_run/overview` | 取得訓練概覽 | `id`, `created_at`, `training_plan_name`, `total_weeks` |
| `GET /plan/race_run/week/{planId}` | 取得週課表 | 完整週課表資料 |

### 3.2 緩存 TTL 設定

| 緩存項目 | TTL | 說明 |
|----------|-----|------|
| Plan Status | 8 小時 | 決定 UI 顯示狀態的核心數據 |
| Overview | 24 小時 | 訓練計畫基本資訊 |
| Weekly Plan | 7 天 | 週課表內容（不常變動）|

### 3.3 緩存策略

採用 **Stale-While-Revalidate (SWR)** 策略：

1. **Track A（立即返回）**：如果緩存存在，立即返回緩存數據（即使過期）
2. **Track B（背景刷新）**：同時在背景發起 API 請求更新緩存

**優點**：
- 用戶體驗流暢（不需等待 API 回應）
- API 失敗時不影響已顯示的內容

---

## 四、App 啟動流程（乾淨啟動）

### 4.1 觸發條件

App 被完全關閉（Killed）後重新啟動

### 4.2 執行順序

```
TrainingPlanView.task
    │
    └── TrainingPlanViewModel.initialize()
            │
            ├── Step 0: 載入 Workout 數據
            │   └── workoutRepository.refreshWorkouts()
            │   └── 更新 cachedAllWorkouts
            │
            ├── Step 1: loadPlanStatus(shouldResetSelectedWeek: true)
            │   ├── 取得 Plan Status API（使用 SWR 策略）
            │   ├── 更新 planStatusResponse
            │   ├── 更新 currentWeek = status.currentWeek
            │   └── 重置 selectedWeek = status.currentWeek
            │
            ├── Step 2: 載入 Training Overview
            │   └── weeklyPlanVM.loadOverview()
            │
            ├── Step 3: 根據 nextAction 決定
            │   ├── viewPlan:
            │   │   ├── weeklyPlanVM.loadWeeklyPlan()
            │   │   ├── loadWorkoutsForCurrentWeek()
            │   │   └── updatePlanStatus(from: weeklyPlanVM.state)
            │   │       → planStatus = .ready(plan)
            │   │
            │   ├── trainingCompleted:
            │   │   ├── weeklyPlanVM.state = .empty
            │   │   └── planStatus = .completed
            │   │
            │   └── 其他 (createSummary/createPlan/noActivePlan):
            │       ├── weeklyPlanVM.state = .empty
            │       └── planStatus = .noPlan
            │
            └── Step 4: 設置 hasInitialized = true
```

### 4.3 重要行為

- `selectedWeek` 會被**重置**為 `currentWeek`
- 緩存策略：優先使用緩存，背景刷新 API
- 根據 `nextAction` 設置正確的 `planStatus`

---

## 五、App 背景恢復流程

### 5.1 觸發條件

App 從背景恢復到前台（不是重新啟動）

### 5.2 執行順序

```
TrainingPlanView.onReceive(willEnterForegroundNotification)
    │
    └── refreshWorkouts()
            │
            └── viewModel.initialize(force: true)
                    │
                    └── 執行完整初始化流程（同上）

AppViewModel.onAppBecameActive()
    │
    ├── 1. 檢查 App 是否就緒
    │
    ├── 2. 跨週檢測
    │   ├── 比較 lastActiveMonday vs 當前週一
    │   │
    │   ├── 相同 → 不跨週
    │   │   └── 不發布事件（TrainingPlanView 已執行 initialize）
    │   │
    │   └── 不同 → 跨週！
    │       └── 發布 weekChanged 事件
    │       └── 更新 lastActiveMonday
    │
    └── 3. 刷新 Workouts
```

### 5.3 weekChanged 事件處理

當 TrainingPlanViewModel 收到 `weekChanged` 事件：

```swift
subscribeToEvent("weekChanged") {
    // 1. 顯示 loading 狀態
    planStatus = .loading

    // 2. 強制刷新 plan status（跳過緩存），並重置 selectedWeek
    await loadPlanStatus(skipCache: true, shouldResetSelectedWeek: true)

    // 3. 根據 nextAction 決定下一步
    guard let response = planStatusResponse else {
        planStatus = .noPlan
        return
    }

    if response.nextAction == .viewPlan {
        // 有課表可顯示
        await weeklyPlanVM.loadWeeklyPlan()
        await loadWorkoutsForCurrentWeek()
        updatePlanStatus(from: weeklyPlanVM.state)
    } else if response.nextAction == .trainingCompleted {
        // 訓練已完成
        weeklyPlanVM.state = .empty
        planStatus = .completed
    } else {
        // 需要產生週回顧或課表
        weeklyPlanVM.state = .empty
        planStatus = .noPlan
    }
}
```

### 5.4 重要行為

- **未跨週**：`selectedWeek` 由 `initialize(force: true)` 決定（會重置到 currentWeek）
- **已跨週**：`selectedWeek` 重置為新的 `currentWeek`
- **關鍵修復**：weekChanged 事件處理器現在會根據 `nextAction` 正確更新 `planStatus`

---

## 六、跨週檢測機制

### 6.1 檢測原理

比較兩個日曆週一（基於用戶本地時區）：
- `lastActiveMonday`：上次 App 活躍時記錄的週一
- `currentCalendarMonday()`：當前時間計算的週一

### 6.2 週一計算方式

使用 Gregorian 日曆，週日為 weekday=1，週一為 weekday=2：
- 計算公式：`offsetToMonday = (weekday + 5) % 7`
- 從今天減去 offset 天數得到本週一

### 6.3 時區考量

- 使用 `TimeZone.current` 確保使用用戶當地時區
- 週日 23:59:59 (本地時間) → 週一 00:00:00 (本地時間) = 跨週

### 6.4 記錄時機

| 時機 | 動作 |
|------|------|
| App 啟動時 | 在 `initializeApp()` 中記錄 `lastActiveMonday` |
| App 恢復時 | 在 `onAppBecameActive()` 執行檢測後更新 `lastActiveMonday` |

---

## 七、週數切換機制

### 7.1 觸發方式

1. **WeekSelectorSheet**：用戶點擊「課表」按鈕
2. **ReturnToCurrentWeekButton**：用戶點擊「返回本週」按鈕

### 7.2 執行流程

```
fetchWeekPlan(week: Int)
    │
    ├── 1. planStatus = .loading
    │
    ├── 2. loadPlanStatus(skipCache: true, shouldResetSelectedWeek: false)
    │   ├── 刷新 plan status
    │   └── 保留 selectedWeek（不重置）
    │
    ├── 3. weeklyPlanVM.selectWeek(week)
    │   ├── selectedWeek = week
    │   └── 載入該週課表
    │
    ├── 4. loadWorkoutsForCurrentWeek()
    │   └── 根據 selectedWeek 載入訓練記錄
    │
    └── 5. updatePlanStatus(from: weeklyPlanVM.state)
        └── planStatus = .ready(plan) 或 .error
```

### 7.3 重要行為

- 先刷新 `planStatus` 確保 `currentWeek` 正確
- 使用 `shouldResetSelectedWeek: false` 保留用戶選擇
- 最後手動更新 `planStatus` 以反映載入結果

---

## 八、產生下週課表機制

### 8.1 GenerateNextWeekButton 顯示條件

```swift
if let nextWeekInfo = viewModel.nextWeekInfo,
   nextWeekInfo.canGenerate,        // 後端允許產生
   !nextWeekInfo.hasPlan,           // 下週還沒有課表
   viewModel.selectedWeek == viewModel.currentWeek {  // 正在查看當前週
    GenerateNextWeekButton(...)
}
```

### 8.2 產生流程（完整）

```
GenerateNextWeekButton 被點擊
    │
    └── generateNextWeekPlan(nextWeekInfo:)
            │
            ├── 檢查 requiresCurrentWeekSummary
            │   │
            │   ├── true → 需要先產生週回顧
            │   │   ├── summaryVM.pendingTargetWeek = weekNumber
            │   │   ├── await summaryVM.createWeeklySummary(weekNumber:)
            │   │   │
            │   │   ├── 如果有調整項目
            │   │   │   └── 顯示調整確認 Sheet → 等待用戶確認
            │   │   │
            │   │   └── 如果無調整項目
            │   │       └── 顯示週回顧 Sheet → 等待用戶點擊「產生下週課表」
            │   │
            │   └── false → 直接呼叫 generateNextWeekPlan(targetWeek:)
            │
            └── 用戶從週回顧 Sheet 點擊「產生下週課表」
                └── confirmAdjustmentsAndGenerateNextWeek(targetWeek:)
                    ├── 確認調整項目（如有）
                    └── generateNextWeekPlan(targetWeek:, forceGenerate: true)
```

### 8.3 generateNextWeekPlan(targetWeek:, forceGenerate:) 核心流程

```swift
func generateNextWeekPlan(targetWeek: Int, forceGenerate: Bool = false) async {
    // ✅ Step 1: 設置 loading 狀態（關鍵！防止 UI 刷新時顯示舊課表）
    isLoadingAnimation = true
    planStatus = .loading

    // ✅ Step 2: 設置 selectedWeek 為目標週數
    weeklyPlanVM.selectedWeek = targetWeek

    // ✅ Step 3: 產生週計畫
    await weeklyPlanVM.generateWeeklyPlan(targetWeek: targetWeek)

    // ✅ Step 4: 立即更新 planStatus（關鍵！必須在 loadWorkoutsForCurrentWeek 之前）
    updatePlanStatus(from: weeklyPlanVM.state)

    // ✅ Step 5: 刷新 plan status（更新 currentWeek，但不重置 selectedWeek）
    await loadPlanStatus(skipCache: true, shouldResetSelectedWeek: false)

    // ✅ Step 6: 載入該週的訓練記錄
    await loadWorkoutsForCurrentWeek()

    // ✅ Step 7: 再次確認 planStatus（防止任何異常）
    updatePlanStatus(from: weeklyPlanVM.state)

    isLoadingAnimation = false

    // ✅ Step 8: 顯示成功 Toast
    if case .ready = planStatus {
        successToast = L10n.Success.planGenerated.localized
    }
}
```

### 8.4 forceGenerate 參數

- `forceGenerate: false`（預設）：檢查是否需要先產生週回顧，如已存在則顯示給用戶查看
- `forceGenerate: true`：跳過週回顧檢查，直接產生課表（從週回顧 Sheet 點擊時使用）

### 8.5 關鍵修復說明

**問題**：產生課表後顯示舊課表，需滑掉 App 才會顯示新課表

**根本原因**：
1. `loadWorkoutsForCurrentWeek()` 內部呼叫 `objectWillChange.send()`
2. 這觸發 SwiftUI 重新渲染 UI
3. 但此時 `planStatus` 還是舊值（尚未執行 `updatePlanStatus`）
4. UI 根據舊的 `planStatus` 顯示舊課表

**修復方案**：
1. 在流程開始時設置 `planStatus = .loading`
2. 在 `loadWorkoutsForCurrentWeek()` **之前**執行 `updatePlanStatus()`
3. 結束時再次確認 `planStatus`

---

## 九、情境矩陣分析

### 9.1 App 乾淨啟動情境

| 計畫狀態 | API nextAction | planStatus | UI 顯示 |
|----------|----------------|------------|---------|
| 當週有課表 | `viewPlan` | `.ready(plan)` | 週課表內容 |
| 當週沒課表，需產生週回顧 | `createSummary` | `.noPlan` | NewWeekPromptView（產生週回顧按鈕）|
| 當週沒課表，可直接產生 | `createPlan` | `.noPlan` | NewWeekPromptView |
| 訓練已完成 | `trainingCompleted` | `.completed` | FinalWeekPromptView |
| 無啟動計畫 | `noActivePlan` | `.noPlan` | NewWeekPromptView |

### 9.2 App 背景恢復 - 未跨週

| 情境 | 行為 |
|------|------|
| 任何狀態 | `initialize(force: true)` 重置 selectedWeek 並刷新所有數據 |

### 9.3 App 背景恢復 - 已跨週

| 之前狀態 | 之後 API 回應 | planStatus | 行為 |
|----------|--------------|------------|------|
| Week 3 有課表 | Week 4: `viewPlan` | `.ready(plan)` | 自動切換顯示 Week 4 課表 |
| Week 3 有課表 | Week 4: `createSummary` | `.noPlan` | 顯示「產生週回顧」按鈕 |
| Week 3 沒課表 | Week 4: 任何 | 根據 nextAction | 根據新狀態顯示對應 UI |

### 9.4 週數切換情境

| 操作 | selectedWeek | currentWeek | 顯示 |
|------|--------------|-------------|------|
| 切換到過去週（有課表） | < currentWeek | 不變 | 該週課表 |
| 切換到過去週（無課表） | < currentWeek | 不變 | 無資料或錯誤 |
| 切換到未來週（已產生） | > currentWeek | 不變 | 該週課表 + ReturnToCurrentWeekButton |
| 切換回當前週 | = currentWeek | 不變 | 當前週課表 |

### 9.5 產生下週課表情境

| 條件 | 顯示 GenerateNextWeekButton | 點擊後流程 |
|------|---------------------------|------------|
| 週六日，下週未產生，需週回顧 | ✅ | 產生週回顧 → 顯示 Sheet → 用戶點擊產生 → 顯示新課表 |
| 週六日，下週未產生，已有週回顧 | ✅ | 顯示週回顧 Sheet → 用戶點擊產生 → 顯示新課表 |
| 週六日，下週已產生 | ❌ | 不顯示 |
| 非週六日 | ❌（`canGenerate: false`） | 不顯示 |
| 正在查看其他週 | ❌ | 不顯示 |

### 9.6 產生課表後的 UI 行為

| 情境 | selectedWeek | currentWeek | 行為 |
|------|--------------|-------------|------|
| 週一產生本週課表 | = currentWeek | = selectedWeek | 顯示新課表 |
| 週日產生下週課表 | = targetWeek | < selectedWeek | 顯示新課表 + ReturnToCurrentWeekButton |

**關鍵規則**：產生課表後一律顯示新產生的課表，即使是週日產生下週課表，也會顯示下週課表並提示用戶可以返回本週。

---

## 十、緩存策略詳解

### 10.1 一般讀取（getPlanStatus / getWeeklyPlan / getOverview）

```
1. 檢查本地緩存是否存在
   ├── 存在 → 立即返回緩存（即使過期）
   │         同時啟動背景刷新
   │
   └── 不存在 → 從 API 獲取並緩存
```

### 10.2 強制刷新（refreshPlanStatus）

```
1. 跳過緩存檢查
2. 直接從 API 獲取
3. 更新緩存
4. 返回結果
```

### 10.3 背景刷新失敗處理

- 背景刷新失敗**不影響**已顯示的緩存數據
- 日誌記錄失敗原因，但不拋出錯誤
- 用戶體驗不受影響

### 10.4 HTTPClient 重試機制

針對 5xx 伺服器錯誤：
- 最多重試 3 次
- 總時間限制 10 秒
- 指數退避：1秒 → 2秒 → 4秒

---

## 十一、事件驅動更新機制

### 11.1 事件類型一覽

| 事件 | 觸發時機 | 處理邏輯 |
|------|----------|----------|
| `weekChanged` | App 從背景恢復且跨週 | 強制刷新 planStatus，重置 selectedWeek，根據 nextAction 更新 UI |
| `onboardingCompleted` | 用戶完成 Onboarding | 清除緩存，重新初始化 |
| `userLogout` | 用戶登出 | 清除緩存，重置所有狀態 |
| `dataChanged.trainingPlan` | 課表被修改（EditScheduleView） | 刷新週課表，更新 planStatus |
| `targetUpdated` | 訓練目標被修改 | 刷新 overview 和 planStatus，根據 nextAction 更新 UI |
| `dataChanged.user` | 用戶登入 | 清除緩存，重新初始化 |

### 11.2 事件處理代碼

```swift
// weekChanged 事件
subscribeToEvent("weekChanged") {
    planStatus = .loading
    await loadPlanStatus(skipCache: true, shouldResetSelectedWeek: true)

    guard let response = planStatusResponse else {
        planStatus = .noPlan
        return
    }

    if response.nextAction == .viewPlan {
        await weeklyPlanVM.loadWeeklyPlan()
        await loadWorkoutsForCurrentWeek()
        updatePlanStatus(from: weeklyPlanVM.state)
    } else if response.nextAction == .trainingCompleted {
        weeklyPlanVM.state = .empty
        planStatus = .completed
    } else {
        weeklyPlanVM.state = .empty
        planStatus = .noPlan
    }
}

// dataChanged.trainingPlan 事件
subscribeToEvent("dataChanged.trainingPlan") {
    await weeklyPlanVM.refreshWeeklyPlan()
    await loadWorkoutsForCurrentWeek()
    updatePlanStatus(from: weeklyPlanVM.state)
}

// targetUpdated 事件
subscribeToEvent("targetUpdated") {
    await weeklyPlanVM.loadOverview()
    await loadPlanStatus()

    if let response = planStatusResponse {
        if response.nextAction == .viewPlan {
            await weeklyPlanVM.loadWeeklyPlan()
            updatePlanStatus(from: weeklyPlanVM.state)
        } else if response.nextAction == .trainingCompleted {
            weeklyPlanVM.state = .empty
            planStatus = .completed
        } else {
            weeklyPlanVM.state = .empty
            planStatus = .noPlan
        }
    }
}
```

---

## 十二、代碼實現參考

### 12.1 planStatus 更新邏輯

**關鍵方法**：`updatePlanStatus(from:)`

```swift
private func updatePlanStatus(from state: ViewState<WeeklyPlan>) {
    switch state {
    case .loading:
        planStatus = .loading
    case .loaded(let plan):
        planStatus = .ready(plan)
    case .empty:
        planStatus = .noPlan
    case .error(let error):
        planStatus = .error(error as NSError)
    }
}
```

### 12.2 initialize() 完整流程

```swift
func initialize(force: Bool = false) async {
    guard force || !hasInitialized else { return }

    planStatus = .loading

    // Step 0: 載入 Workout 數據
    do {
        let workouts = try await workoutRepository.refreshWorkouts()
        cachedAllWorkouts = workouts
    } catch {
        // 嘗試從緩存載入
        let cachedWorkouts = try? await workoutRepository.getAllWorkouts()
        cachedAllWorkouts = cachedWorkouts ?? []
    }

    // Step 1: 載入 Plan Status
    await loadPlanStatus(shouldResetSelectedWeek: true)

    guard let response = planStatusResponse else {
        planStatus = .noPlan
        return
    }

    // Step 2: 載入 Overview
    await weeklyPlanVM.loadOverview()

    // Step 3: 根據 nextAction 處理
    if response.nextAction == .viewPlan {
        await weeklyPlanVM.loadWeeklyPlan()
        await loadWorkoutsForCurrentWeek()
        updatePlanStatus(from: weeklyPlanVM.state)
    } else if response.nextAction == .trainingCompleted {
        weeklyPlanVM.state = .empty
        planStatus = .completed
    } else {
        weeklyPlanVM.state = .empty
        planStatus = .noPlan
    }

    hasInitialized = true
}
```

### 12.3 fetchWeekPlan() 完整流程

```swift
func fetchWeekPlan(week: Int) async {
    planStatus = .loading

    // 先刷新 plan status 確保 currentWeek 正確
    await loadPlanStatus(skipCache: true, shouldResetSelectedWeek: false)

    // 切換週次
    await weeklyPlanVM.selectWeek(week)

    // 載入訓練記錄
    await loadWorkoutsForCurrentWeek()

    // 更新 planStatus
    updatePlanStatus(from: weeklyPlanVM.state)
}
```

### 12.4 generateNextWeekPlan() 完整流程（關鍵修復後）

```swift
func generateNextWeekPlan(targetWeek: Int, forceGenerate: Bool = false) async {
    // ... 週回顧檢查邏輯（略）...

    isLoadingAnimation = true

    // ✅ 關鍵修復：先設置 planStatus = .loading
    planStatus = .loading

    // ✅ 先設置 selectedWeek 為目標週數
    weeklyPlanVM.selectedWeek = targetWeek

    // ✅ 產生週計畫
    await weeklyPlanVM.generateWeeklyPlan(targetWeek: targetWeek)

    // ✅ 關鍵修復：產生課表後立即更新 planStatus
    // 必須在 loadWorkoutsForCurrentWeek 之前執行
    updatePlanStatus(from: weeklyPlanVM.state)

    // 刷新計畫狀態（不重置 selectedWeek）
    await loadPlanStatus(skipCache: true, shouldResetSelectedWeek: false)

    // ✅ 載入該週的訓練記錄
    await loadWorkoutsForCurrentWeek()

    // ✅ 再次確認 planStatus
    updatePlanStatus(from: weeklyPlanVM.state)

    isLoadingAnimation = false

    if case .ready = planStatus {
        successToast = L10n.Success.planGenerated.localized
    }
}
```

---

## 十三、流程圖

### 13.1 App 啟動/恢復總覽

```
┌─────────────────────────────────────────────────────────────────┐
│                      App 啟動/恢復流程                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  App 狀態？                    │
              └───────────────────────────────┘
                     │              │
          ┌──────────┘              └──────────┐
          ▼                                    ▼
   ┌──────────────┐                    ┌──────────────┐
   │ 重啟 (Killed) │                    │ 恢復 (BG)    │
   └──────────────┘                    └──────────────┘
          │                                    │
          ▼                                    ▼
   ┌──────────────┐                    ┌──────────────────────┐
   │ initialize() │                    │ initialize(force:true)│
   └──────────────┘                    │ + 跨週檢測            │
          │                            └──────────────────────┘
          │                                    │
          │                              ┌─────┴─────┐
          │                              │           │
          │                           跨週?        未跨週
          │                              │           │
          │                              ▼           │
          │                      weekChanged 事件    │
          │                              │           │
          ▼                              ▼           ▼
   ┌───────────────────────────────────────────────────┐
   │ loadPlanStatus(shouldResetSelectedWeek)            │
   │ → 更新 currentWeek, selectedWeek                   │
   └───────────────────────────────────────────────────┘
                    │
                    ▼
           ┌──────────────┐
           │ nextAction   │
           └──────────────┘
                    │
        ┌──────────┼──────────┬──────────┐
        ▼          ▼          ▼          ▼
   ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌──────────┐
   │viewPlan │ │createSum│ │createPln│ │completed │
   └─────────┘ └─────────┘ └─────────┘ └──────────┘
        │          │          │          │
        ▼          └────┬─────┘          ▼
   載入課表             ▼           planStatus
   載入workouts    planStatus      = .completed
   updatePlanStatus = .noPlan
   → .ready(plan)
```

### 13.2 週數切換流程

```
┌─────────────────────────────────────────┐
│     用戶點擊切換週數                       │
│  (WeekSelectorSheet / ReturnButton)      │
└─────────────────────────────────────────┘
                    │
                    ▼
           ┌──────────────┐
           │ fetchWeekPlan │
           └──────────────┘
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
   planStatus = .loading    loadPlanStatus
                           (skipCache: true)
                                  │
                                  ▼
                          selectWeek(week)
                                  │
                                  ▼
                     loadWorkoutsForCurrentWeek
                                  │
                                  ▼
                         updatePlanStatus
                                  │
                                  ▼
                        planStatus = .ready
```

### 13.3 產生下週課表流程（修復後）

```
┌─────────────────────────────────────────┐
│     GenerateNextWeekButton 被點擊         │
└─────────────────────────────────────────┘
                    │
                    ▼
           ┌──────────────┐
           │ 需要先產生    │
           │ 週回顧?       │
           └──────────────┘
              │         │
         是   │         │ 否
              ▼         ▼
   ┌──────────────┐  ┌──────────────┐
   │ 產生週回顧    │  │ 直接產生課表  │
   └──────────────┘  └──────────────┘
              │              │
              ▼              │
   ┌──────────────────┐      │
   │ 有調整項目?        │      │
   └──────────────────┘      │
         │        │          │
      是 │        │ 否       │
         ▼        ▼          │
   顯示調整    顯示週回顧     │
   確認Sheet   Sheet         │
         │        │          │
         └────┬───┘          │
              ▼              │
   用戶點擊「產生下週課表」    │
              │              │
              └──────────────┤
                             │
                             ▼
              ┌──────────────────────────┐
              │ generateNextWeekPlan     │
              │ (forceGenerate: true)    │
              └──────────────────────────┘
                             │
              ┌──────────────┴──────────────┐
              │ ✅ 關鍵修復流程               │
              │                              │
              │ 1. planStatus = .loading    │
              │ 2. selectedWeek = targetWeek │
              │ 3. generateWeeklyPlan()      │
              │ 4. updatePlanStatus() ← 關鍵 │
              │ 5. loadPlanStatus()          │
              │ 6. loadWorkoutsForCurrentWeek│
              │ 7. updatePlanStatus() 再確認 │
              └──────────────────────────────┘
                             │
                             ▼
                    成功 Toast 顯示
                    UI 顯示新產生的課表
```

---

## 十四、關鍵修復說明

### 14.1 問題：產生課表後顯示舊課表

**症狀**：
- 用戶點擊「產生下週課表」
- 課表產生成功（後端回應正確）
- 但 UI 仍顯示舊課表
- 需要滑掉 App 重開才會顯示新課表

**根本原因**：
```
generateNextWeekPlan()
    │
    ├── weeklyPlanVM.generateWeeklyPlan()
    │   └── state = .loaded(新課表)  ← 新課表已載入到 weeklyPlanVM.state
    │
    ├── loadPlanStatus()
    │
    ├── loadWorkoutsForCurrentWeek()
    │   └── objectWillChange.send()  ← 觸發 UI 重新渲染
    │                                   但此時 planStatus 還是舊值！
    │
    └── updatePlanStatus()  ← 太晚了，UI 已經用舊的 planStatus 渲染完成
```

**修復方案**：
```
generateNextWeekPlan()
    │
    ├── planStatus = .loading  ← 先設為 loading，防止顯示舊課表
    │
    ├── weeklyPlanVM.generateWeeklyPlan()
    │   └── state = .loaded(新課表)
    │
    ├── updatePlanStatus()  ← 立即更新 planStatus = .ready(新課表)
    │
    ├── loadPlanStatus()
    │
    ├── loadWorkoutsForCurrentWeek()
    │   └── objectWillChange.send()  ← 現在 planStatus 已經是新值
    │
    └── updatePlanStatus()  ← 再次確認
```

### 14.2 相關檔案

| 檔案 | 修改內容 |
|------|----------|
| `TrainingPlanViewModel.swift` | `generateNextWeekPlan()` 方法 |

---

## 附錄：相關檔案參考

| 檔案 | 職責 |
|------|------|
| `AppViewModel.swift` | App 生命週期管理、跨週檢測 |
| `TrainingPlanViewModel.swift` | 週課表 UI 狀態管理、事件訂閱 |
| `WeeklyPlanViewModel.swift` | 週課表載入邏輯 |
| `TrainingPlanView.swift` | 主視圖，根據 planStatus 顯示不同 UI |
| `TrainingPlanRepositoryImpl.swift` | 緩存策略實作 |
| `TrainingPlanLocalDataSource.swift` | 本地緩存存取 |
| `WeekDateService.swift` | 週日期計算、跨週檢測 |
| `CacheEventBus.swift` | 事件發布/訂閱 |
| `GenerateNextWeekButton.swift` | 產生下週課表按鈕 |
| `WeekSelectorSheet.swift` | 週數切換 Sheet |
| `PlanStatusResponse.swift` | Plan Status API 回應模型 |
| `HTTPClient.swift` | HTTP 通訊、重試機制 |
