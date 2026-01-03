# Workout 顯示問題的架構分析與重構方案

## 問題現象

用戶報告：每日訓練卡片在**初次加載時**不顯示已完成的 workout，需要切換到其他頁面再切回來才會顯示。

## ✅ 根本原因（已找到）

**重構時遺漏了 `.workoutsDidUpdate` 通知監聽器！**

### 對比分析

| 版本 | 通知監聽 | 結果 |
|------|---------|------|
| 舊版 `TrainingPlanViewModel.swift.old` | ✅ 有監聽 `.workoutsDidUpdate` (line 610-645) | 正常顯示 |
| 新版 `TrainingPlanViewModel.swift` | ❌ 完全沒有監聽 | 首次不顯示 |

### 執行時序說明

```
T1: App 啟動
T2: AppStateManager.setupServices()
T3: → UnifiedWorkoutManager.loadWorkouts() (非同步，開始載入)
T4: TrainingPlanView 出現
T5: → viewModel.initialize()
T6: → loadWorkoutsForCurrentWeek()
T7: → UnifiedWorkoutManager.shared.workouts = [] (此時還是空的！)
T8: → workoutsByDayV2 = {} (空)
T9: → planStatus = .ready(plan) → UI 渲染（沒有 workouts）

T10: UnifiedWorkoutManager 完成載入
T11: → NotificationCenter.post(name: .workoutsDidUpdate)
T12: ❌ 新版 ViewModel 沒有監聽，不做任何事

T13: 用戶切換頁面再切回來
T14: → 某些刷新邏輯被觸發
T15: → workouts 終於正確顯示
```

### 修復方案

在 `setupBindings()` 中添加 `.workoutsDidUpdate` 通知監聯器，當 `UnifiedWorkoutManager` 完成載入時自動重新載入 workouts。

## 當前數據流分析

### 1. 入口點：TrainingPlanView (line 182)
```swift
.task {
    await viewModel.initialize()
}
```

### 2. ViewModel 初始化流程 (TrainingPlanViewModel.swift:454)
```swift
func initialize() async {
    await loadPlanStatus()                    // 步驟 1: 加載訓練計劃狀態
    guard let response = planStatusResponse else { return }

    await weeklyPlanVM.loadOverview()         // 步驟 2: 加載訓練總覽

    if response.nextAction == .viewPlan {
        await weeklyPlanVM.loadWeeklyPlan()   // 步驟 3: 加載週計劃
    }

    await loadWorkoutsForCurrentWeek()        // 步驟 4: 加載 workouts ⚠️ 太晚了！
}
```

### 3. 🔴 問題根源：響應式綁定導致過早的 UI 更新

**setupBindings() (line 413-420)**
```swift
private func setupBindings() {
    // ⚠️ 這個 Combine 訂閱會在 weeklyPlanVM.$state 變化時立即觸發
    weeklyPlanVM.$state
        .receive(on: DispatchQueue.main)
        .sink { [weak self] state in
            self?.updatePlanStatus(from: state)  // ← 立即更新 UI！
        }
        .store(in: &cancellables)
}
```

**updatePlanStatus() (line 437-449)**
```swift
private func updatePlanStatus(from state: ViewState<WeeklyPlan>) {
    switch state {
    case .loaded(let plan):
        planStatus = .ready(plan)  // ← 觸發 View 渲染，但此時 workoutsByDayV2 還是空的！
    // ...
    }
}
```

### 4. 執行時序圖

```
時間軸 →

T1: initialize() 開始
T2: loadPlanStatus() 完成
T3: loadOverview() 完成
T4: loadWeeklyPlan() 開始
T5: ↓ weeklyPlanVM.$state 變為 .loaded(plan)
T6: ↓ setupBindings() 的 sink 觸發
T7: ↓ updatePlanStatus() 執行
T8: ↓ planStatus = .ready(plan)  ⚠️ UI 開始渲染！
T9: ↓ View 讀取 workoutsByDayV2 → 空字典 {}
T10: loadWeeklyPlan() 完成
T11: loadWorkoutsForCurrentWeek() 開始
T12: workoutsByDayV2 更新為 {1: [workout1], 3: [workout2]}  ⚠️ 但 View 已經渲染完成！
T13: loadWorkoutsForCurrentWeek() 完成
```

**核心問題**：在 T8 時刻，`planStatus = .ready(plan)` 觸發 View 渲染，但此時 `workoutsByDayV2` 仍是空字典。雖然 T12 時更新了數據，但 SwiftUI 可能因為字典突變檢測問題而不重新渲染。

## 架構問題診斷

### 1. **關注點分離違反 (Violation of Separation of Concerns)**

TrainingPlanViewModel 混合了兩種數據加載機制：

- **機制 A**: 響應式綁定 (`setupBindings()`)
  - 自動訂閱 `weeklyPlanVM.$state`
  - 自動更新 `planStatus`
  - 無法控制時序

- **機制 B**: 順序式加載 (`initialize()`)
  - 手動按順序執行 async 操作
  - 期望在特定時機更新 UI
  - 但被機制 A 的響應式更新搶先

**衝突**：機制 A 和機制 B 在競爭 UI 更新的控制權。

### 2. **多重真相來源 (Multiple Sources of Truth)**

- `weeklyPlanVM.$state` 是一個真相來源 (通過 setupBindings)
- `initialize()` 手動控制加載順序是另一個真相來源
- 哪一個應該決定 UI 狀態？不明確！

### 3. **缺乏原子性數據加載 (Lack of Atomic Data Loading)**

從 **Clean Architecture** 角度：
- **Use Case**: "顯示本週訓練計劃"
- **所需數據**: 週計劃 + 本週 workouts
- **當前實現**: 兩個分離的 async 操作，中間觸發 UI 更新

```
❌ 當前實現：
loadWeeklyPlan() → UI 更新 (planStatus = .ready) → loadWorkouts()

✅ 應該的實現：
loadWeeklyPlanWithWorkouts() → 一次性獲取所有數據 → UI 更新
```

### 4. **Published Dictionary 深度觀察問題**

```swift
@Published var workoutsByDayV2: [Int: [WorkoutV2]] = [:]
```

SwiftUI 的 `@Published` 只觀察引用變化，不觀察字典內容的深度變化。

- ✅ 觸發更新: `workoutsByDayV2 = newDict`
- ❌ 可能不觸發: `workoutsByDayV2[key] = value`

當前代碼使用 `self.workoutsByDayV2 = grouped`，理論上應該觸發更新，但由於 View 已經在 T8 時刻渲染完成並緩存結果，後續的字典更新可能不會觸發重新渲染。

## Clean Architecture 重構方案

### 目標

遵循 Clean Architecture 原則，確保：
1. **單一數據源** (Single Source of Truth)
2. **原子性加載** (Atomic Data Loading)
3. **明確的依賴方向** (Clear Dependency Direction)

### 層級設計

```
┌─────────────────────────────────────────────┐
│   UI Layer (View)                           │
│   - TrainingPlanView                        │
│   - WeekTimelineView                        │
└─────────────────┬───────────────────────────┘
                  │ 觀察 @Published 屬性
┌─────────────────▼───────────────────────────┐
│   Presentation Layer (ViewModel)            │
│   - TrainingPlanViewModel                   │
│   - 統一管理 planStatus                     │
│   - 確保數據完整後才更新 UI                 │
└─────────────────┬───────────────────────────┘
                  │ 調用 Use Cases
┌─────────────────▼───────────────────────────┐
│   Domain Layer (Use Cases)                  │
│   - LoadWeeklyPlanWithWorkoutsUseCase       │
│   - 原子性加載週計劃 + workouts             │
└─────────────────┬───────────────────────────┘
                  │ 調用 Repositories
┌─────────────────▼───────────────────────────┐
│   Data Layer (Repository + Service)         │
│   - TrainingPlanRepository                  │
│   - UnifiedWorkoutManager                   │
└─────────────────────────────────────────────┘
```

### 方案 A: 移除響應式綁定，完全手動控制（推薦）

#### 核心思路
- **移除** `setupBindings()` 中導致過早 UI 更新的訂閱
- 在 `initialize()` 中**原子性加載**週計劃和 workouts
- 確保**所有數據準備完畢後**才設置 `planStatus = .ready(plan)`

#### 具體修改

**1. 修改 setupBindings() - 移除自動 planStatus 更新**
```swift
private func setupBindings() {
    // ❌ 刪除這個自動訂閱
    // weeklyPlanVM.$state
    //     .receive(on: DispatchQueue.main)
    //     .sink { [weak self] state in
    //         self?.updatePlanStatus(from: state)
    //     }
    //     .store(in: &cancellables)

    // ✅ 保留其他必要的訂閱
    summaryVM.$isGenerating
        .receive(on: DispatchQueue.main)
        .assign(to: &$isLoadingAnimation)

    summaryVM.$summariesState
        .receive(on: DispatchQueue.main)
        .sink { [weak self] state in
            self?.weeklySummaries = state.data ?? []
            self?.isLoadingWeeklySummaries = state.isLoading
        }
        .store(in: &cancellables)
}
```

**2. 修改 initialize() - 原子性加載**
```swift
func initialize() async {
    Logger.debug("[TrainingPlanVM] Initializing...")

    // 顯示 loading 狀態
    planStatus = .loading

    // 步驟 1: 加載計劃狀態
    await loadPlanStatus()

    guard let response = planStatusResponse else {
        Logger.error("[TrainingPlanVM] No plan status response")
        planStatus = .noPlan
        return
    }

    // 步驟 2: 加載訓練總覽
    await weeklyPlanVM.loadOverview()

    // 步驟 3: 根據 nextAction 決定是否載入週計畫
    if response.nextAction == .viewPlan {
        await weeklyPlanVM.loadWeeklyPlan()

        // ✅ 關鍵修改：立即載入 workouts，在更新 planStatus 之前
        await loadWorkoutsForCurrentWeek()

        // ✅ 所有數據準備完畢後，手動更新 planStatus
        if case .loaded(let plan) = weeklyPlanVM.state {
            planStatus = .ready(plan)
            Logger.debug("[TrainingPlanVM] ✅ All data loaded, UI ready to display")
        } else if case .error(let error) = weeklyPlanVM.state {
            planStatus = .error(error as NSError)
        } else if case .empty = weeklyPlanVM.state {
            planStatus = .noPlan
        }
    } else {
        planStatus = .noPlan
    }
}
```

**3. 修改 refreshWeeklyPlan() - 保持一致性**
```swift
func refreshWeeklyPlan(isManualRefresh: Bool = false) async {
    Logger.debug("[TrainingPlanVM] Refreshing weekly plan (manual: \(isManualRefresh))")

    planStatus = .loading

    // 刷新計畫狀態
    await loadPlanStatus(skipCache: isManualRefresh)

    // 刷新週計畫
    await weeklyPlanVM.refreshWeeklyPlan()

    // ✅ 刷新訓練記錄
    await loadWorkoutsForCurrentWeek()

    // ✅ 所有數據準備完畢後，手動更新 planStatus
    if case .loaded(let plan) = weeklyPlanVM.state {
        planStatus = .ready(plan)
    } else if case .error(let error) = weeklyPlanVM.state {
        planStatus = .error(error as NSError)
    } else if case .empty = weeklyPlanVM.state {
        planStatus = .noPlan
    }
}
```

**4. 修改 fetchWeekPlan() - 切換週次時**
```swift
func fetchWeekPlan(week: Int) async {
    planStatus = .loading

    await weeklyPlanVM.selectWeek(week)

    // ✅ 切換週次後，重新載入訓練記錄
    await loadWorkoutsForCurrentWeek()

    // ✅ 更新 planStatus
    if case .loaded(let plan) = weeklyPlanVM.state {
        planStatus = .ready(plan)
    } else if case .error(let error) = weeklyPlanVM.state {
        planStatus = .error(error as NSError)
    } else if case .empty = weeklyPlanVM.state {
        planStatus = .noPlan
    }
}
```

**5. 強制觸發 objectWillChange（備選方案）**

如果上述修改仍有問題，可以在 `loadWorkoutsForCurrentWeek()` 完成後強制觸發：

```swift
await MainActor.run {
    self.workoutsByDayV2 = grouped
    self.isLoadingWorkouts = false

    // ✅ 強制通知 SwiftUI 重新渲染
    self.objectWillChange.send()
}
```

### 方案 B: 創建 Use Case（更符合 Clean Architecture）

如果時間允許，可以進一步重構：

**1. 創建 Use Case**
```swift
// Domain/UseCases/LoadWeeklyPlanWithWorkoutsUseCase.swift
struct WeeklyPlanWithWorkouts {
    let plan: WeeklyPlan
    let workoutsByDay: [Int: [WorkoutV2]]
    let weekDistance: Double
    let weekIntensity: WeeklyPlan.IntensityTotalMinutes
}

protocol LoadWeeklyPlanWithWorkoutsUseCase {
    func execute(week: Int) async throws -> WeeklyPlanWithWorkouts
}
```

**2. ViewModel 使用 Use Case**
```swift
func initialize() async {
    planStatus = .loading

    do {
        let result = try await loadWeeklyPlanWithWorkoutsUseCase.execute(week: currentWeek)

        // ✅ 原子性更新所有數據
        await MainActor.run {
            self.workoutsByDayV2 = result.workoutsByDay
            self.currentWeekDistance = result.weekDistance
            self.currentWeekIntensity = result.weekIntensity
            self.planStatus = .ready(result.plan)
        }
    } catch {
        planStatus = .error(error as NSError)
    }
}
```

## 推薦實施順序

### Phase 1: 修復當前問題（方案 A）
1. ✅ 移除 `setupBindings()` 中的自動 planStatus 更新
2. ✅ 修改 `initialize()` 確保數據完整後才更新 UI
3. ✅ 修改 `refreshWeeklyPlan()` 和 `fetchWeekPlan()` 保持一致
4. ✅ 測試：初次加載時 workouts 正確顯示

### Phase 2: 深度重構（方案 B，可選）
1. 創建 `LoadWeeklyPlanWithWorkoutsUseCase`
2. 重構 ViewModel 使用 Use Case
3. 移除 `weeklyPlanVM` 的直接依賴，改為通過 Use Case 間接調用

## 測試檢查清單

- [ ] 初次啟動 App，訓練計劃頁面加載後，已完成的 workouts 立即顯示
- [ ] 下拉刷新後，workouts 正確更新
- [ ] 切換到不同週次，workouts 正確對應該週
- [ ] 從其他頁面返回訓練計劃頁面，workouts 仍正確顯示
- [ ] 進入後台再返回前台，workouts 刷新正確

## 總結

**根本原因**：響應式綁定 (`setupBindings()`) 導致 `planStatus` 在 workouts 加載完成前就觸發 UI 渲染。

**解決方案**：移除自動響應式更新，改為手動控制 UI 更新時機，確保所有相關數據（週計劃 + workouts）都準備完畢後才設置 `planStatus = .ready(plan)`。

**Clean Architecture 原則**：
- **單一職責**：ViewModel 負責協調數據加載和 UI 狀態
- **依賴倒置**：ViewModel 依賴 Use Case 抽象，不直接依賴具體實現
- **原子性**：一個 Use Case 完成一個完整的業務操作
