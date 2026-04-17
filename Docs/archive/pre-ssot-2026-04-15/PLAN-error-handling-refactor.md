---
created: 2026-04-13
status: in-progress
---

# PLAN: 錯誤處理架構重構

## 問題總結

兩個問題交織造成「刷課表必定失敗」：

1. **Error chain 多餘包裝**：取消錯誤經 4 次型別轉換，ViewModel 認不出
2. **ObservableObject 廣播重繪**：任何 @Published 變更 → 整個 View 重繪 → .refreshable task 被取消

```
觸發鏈：
RevenueCat Finishing transaction
  → 某個 @Published 變更（或 @EnvironmentObject 變更）
  → SwiftUI 重繪 TrainingPlanV2View
  → .refreshable task 取消
  → URLError.cancelled → HTTPError.cancelled → SystemError.taskCancelled
  → ViewModel catch 認不出 → planStatus = .error → 顯示「載入失敗」
```

## 根因分析

### Error chain（S01+S02 修）

APICallHelper 把 HTTPError.cancelled 多包一層 SystemError.taskCancelled，
ViewModel 的 `catch is CancellationError` 只認 Swift 原生型別，認不出。
`toDomainError()` 已加 `isCancellationError` 兜底（DomainError.swift:150），
但 12 個函式仍用舊的三段式 catch，未走 `shouldShowErrorView`。

### ObservableObject 廣播（S03 修）

`TrainingPlanV2ViewModel` 有 20+ 個 `@Published` 屬性。
`ObservableObject` 的 `objectWillChange` 是**全廣播**——
改 `successToast` 也會觸發讀 `planStatus` 的 View 重繪。

App 只支援 iOS 18+，可以用 `@Observable`。
`@Observable` 是 **property-level tracking**——
只有讀取被改變屬性的 View 才重繪。
`successToast` 變了不會觸發 ScrollView 重繪，`.refreshable` task 不被取消。

**這從根源消除取消的觸發頻率**，讓 S05-C（initialize 恢復）和 S06（detached 隔離）不再需要。

## 目標狀態

```
重構後：

Error chain（2 層）：
  URLError / CancellationError
    → HTTPError                (HTTPClient)
    → DomainError              (Repository)
    → ViewModel 用 shouldShowErrorView 過濾

View 更新（property-level）：
  @Observable ViewModel
    → successToast 變 → 只有 toast overlay 重繪
    → planStatus 變 → 只有課表區域重繪
    → .refreshable task 不被無關屬性變更取消
```

## 任務拆分

### S01: 砍掉 APICallHelper 的錯誤包裝

**改動：** `handleError()` 直接 return 原始錯誤，不再包裝成 SystemError。

```swift
// Before (APICallHelper.swift:129-144):
private func handleError(_ error: Error) -> Error {
    if error.isCancellationError {
        return SystemError.taskCancelled  // ← 多餘包裝
    }
    if let apiError = error as? APIError, apiError.isCancelled {
        return SystemError.taskCancelled
    }
    return error
}

// After:
private func handleError(_ error: Error) -> Error {
    return error  // 保留原始型別
}
```

**Files：**
- `Havital/Havital/Services/Core/APICallHelper.swift`

**Verify：** Build 通過

---

### S02: 統一 TrainingPlanV2ViewModel 的 catch 模式

**統一模板：**

```swift
// 無 loading 的函式：
} catch {
    let domainError = error.toDomainError()
    guard domainError.shouldShowErrorView else { return }
    // 真正的錯誤處理...
}

// 有 loading 的函式（updateOverview, generate* 等）：
} catch {
    self.isLoadingAnimation = false  // ← 取消時也要關 loading
    let domainError = error.toDomainError()
    guard domainError.shouldShowErrorView else { return }
    // 真正的錯誤處理...
}
```

**仍在用舊模式的 12 個函式：**

| # | 函式 | 行號 | 取消時需清理 loading | 特殊錯誤分流 |
|---|------|------|------|------|
| 1 | loadPlanStatus() | 297 | 無 | `.notFound` → `.noPlan`；其他 → `networkError` |
| 2 | refreshPlanStatusResponse() | 330 | 無 | 靜默忽略所有錯誤 |
| 3 | loadPlanOverview() | 402 | 無 | 錯誤 → `networkError` |
| 4 | loadWeeklyPreview() | 442 | 無 | 靜默忽略（輔助資訊） |
| 5 | generateCurrentWeekPlan() | 567 | ✅ `isLoadingAnimation` | `.subscriptionRequired`/`.trialExpired` → paywall |
| 6 | generateWeeklyPlanDirectly() | 665 | ✅ `isLoadingAnimation` | `.subscriptionRequired`/`.trialExpired` → paywall |
| 7 | generateWeeklySummary() | 982 | 無 | `.subscriptionRequired`/`.trialExpired` → paywall |
| 8 | createWeeklySummaryAndShow() | 1012 | ✅ `isLoadingAnimation` | `.subscriptionRequired`/`.trialExpired` → paywall |
| 9 | viewHistoricalSummary() | 1122 | 無 | 錯誤 → `networkError` |
| 10 | updateOverview() | 1146 | ✅ `isLoadingAnimation` | 錯誤 → `networkError` |
| 11 | changeMethodology() | 1216 | 無 | 錯誤 → `networkError` |
| 12 | debugGenerateWeeklySummary() | 1268 | ✅ `isLoadingAnimation` | 錯誤 → `networkError` |

**已用新模式的 3 個函式：**
- loadCurrentWeekPlan() (452)
- refreshDisplayedWeekPlan() (496)
- switchToWeek() (880)

**Files：**
- `Havital/Havital/Features/TrainingPlanV2/Presentation/ViewModels/TrainingPlanV2ViewModel.swift`

**Verify：** Build 通過 + 下拉刷新不顯示「載入失敗」+ loading 動畫不卡住

---

### S03: TrainingPlanV2ViewModel 遷移到 @Observable

**這是本次重構的核心——從根源消除不必要的 View 重繪。**

**ViewModel 改動：**

```swift
// Before:
import Combine

@MainActor
final class TrainingPlanV2ViewModel: ObservableObject, TaskManageable {
    @Published var planStatus: PlanStatusV2 = .loading
    @Published var planOverview: PlanOverviewV2?
    @Published var weeklyPlan: WeeklyPlanV2?
    // ... 20+ 個 @Published
    private var cancellables = Set<AnyCancellable>()
}

// After:
@Observable
@MainActor
final class TrainingPlanV2ViewModel: TaskManageable {
    var planStatus: PlanStatusV2 = .loading
    var planOverview: PlanOverviewV2?
    var weeklyPlan: WeeklyPlanV2?
    // ... 直接 var，@Observable 自動追蹤
    // 移除 cancellables（CacheEventBus 不用 Combine）
}
```

**View 改動：**

```swift
// TrainingPlanV2View.swift:
// Before:
@StateObject private var viewModel: TrainingPlanV2ViewModel
@EnvironmentObject private var authViewModel: AuthenticationViewModel

// After:
@State private var viewModel: TrainingPlanV2ViewModel
@EnvironmentObject private var authViewModel: AuthenticationViewModel  // ← 不動，仍是 ObservableObject
```

```swift
// 子 View（WeekTimelineViewV2, WeekOverviewCardV2 等）：
// Before:
@ObservedObject var viewModel: TrainingPlanV2ViewModel

// After:
@Bindable var viewModel: TrainingPlanV2ViewModel
// 或直接 var viewModel: TrainingPlanV2ViewModel（如果不需要 binding）
```

**initialize() 改用 task(id:)：**

```swift
// Before:
.task {
    await viewModel.initialize()
}
.onChange(of: scenePhase) { old, new in
    if old == .background && new == .active {
        Task { await viewModel.initialize() }
    }
}

// After:
.task(id: scenePhase) {
    guard scenePhase == .active else { return }
    await viewModel.initialize()
}
```

`task(id:)` 在 scenePhase 變化時自動 cancel 舊的、啟動新的。
不需要 `isInitializing` flag，不需要手動 restore previousStatus。

**CacheEventBus 訂閱不受影響：**
CacheEventBus 用自己的 async closure，不走 Combine。`setupEventSubscriptions()` 不用改。

**TaskManageable 不受影響：**
`taskRegistry` 是非 `@Published` 的 `let` 屬性，`@Observable` 不追蹤它。

**需要遷移的 View 檔案（12 處 @ObservedObject / @StateObject 引用）：**

| View 檔案 | 引用方式 | 改為 |
|-----------|---------|------|
| TrainingPlanV2View.swift:6 | `@StateObject` | `@State` |
| TrainingPlanV2View.swift:658 | `@ObservedObject` | `var` 或 `@Bindable` |
| TrainingPlanV2View.swift:762 | `@ObservedObject` | `var` 或 `@Bindable` |
| WeeklySummaryV2View.swift:25 | `@ObservedObject` | `var` 或 `@Bindable` |
| WeekOverviewCardV2.swift:5 | `@ObservedObject` | `var` 或 `@Bindable` |
| TrainingProgressViewV2.swift:5 | `@ObservedObject` | `var` |
| TrainingProgressCardV2.swift:5 | `@ObservedObject` | `var` |
| WeekTimelineViewV2.swift:6 | `@ObservedObject` | `var` |
| WeekTimelineViewV2.swift:62 | `@ObservedObject` | `var` |
| PlanOverviewSheetV2.swift:6 | `@ObservedObject` | `var` 或 `@Bindable` |
| PlanOverviewSheetV2.swift:377 | `@ObservedObject` | `var` |
| EditScheduleViewV2.swift:9 | `@ObservedObject` | `var` 或 `@Bindable` |

**判斷 `var` vs `@Bindable`：** 如果 View 需要用 `$viewModel.someProperty` 做 binding（例如 `.sheet(isPresented: $viewModel.showWeeklySummary)`），用 `@Bindable`。否則用 `var`。

**Files：**
- `Havital/Havital/Features/TrainingPlanV2/Presentation/ViewModels/TrainingPlanV2ViewModel.swift`
- `Havital/Havital/Features/TrainingPlanV2/Presentation/Views/TrainingPlanV2View.swift`
- `Havital/Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift`
- `Havital/Havital/Features/TrainingPlanV2/Presentation/Views/TrainingProgressViewV2.swift`
- `Havital/Havital/Features/TrainingPlanV2/Presentation/Views/EditScheduleViewV2.swift`
- `Havital/Havital/Features/TrainingPlanV2/Presentation/Views/Components/WeekOverviewCardV2.swift`
- `Havital/Havital/Features/TrainingPlanV2/Presentation/Views/Components/TrainingProgressCardV2.swift`
- `Havital/Havital/Features/TrainingPlanV2/Presentation/Views/Components/WeekTimelineViewV2.swift`
- `Havital/Havital/Features/TrainingPlanV2/Presentation/Views/Components/PlanOverviewSheetV2.swift`
- `Havital/Havital/Core/DI/DependencyContainer` — ViewModel factory 可能需要調整

**Verify：**
- Build 通過
- 下拉刷新正常（不被 RevenueCat transaction 取消）
- Sheet 的 binding（showWeeklySummary, isLoadingAnimation 等）正常運作
- CacheEventBus 事件（onboardingCompleted, dataChanged）正常觸發

---

### S04: 統一其他 ViewModel 的 catch 模式（IAP 後）

**目標：** 把其他 ViewModel 的手動取消檢查統一為 shouldShowErrorView pattern。

**Files（依出現次數排序）：**
- `Havital/Havital/Legacy/TrainingPlanManager.swift` — 6 處
- `Havital/Havital/Features/Workout/Presentation/ViewModels/WorkoutDetailViewModelV2.swift` — 3 處
- `Havital/Havital/Features/Workout/Presentation/ViewModels/WorkoutListViewModel.swift` — 3 處
- `Havital/Havital/Features/TrainingPlan/Presentation/ViewModels/TrainingRecordViewModel.swift` — 3 處
- `Havital/Havital/Views/UserProfileView.swift` — 2 處
- `Havital/Havital/Views/Training/DataSyncView.swift` — 2 處
- `Havital/Havital/Views/Onboarding/OnboardingView.swift` — 2 處
- `Havital/Havital/Features/TrainingPlan/Presentation/ViewModels/TrainingPlanViewModel.swift` — 2 處
- 其餘 5 個檔案各 1 處

**Verify：** Build 通過

---

### S05: 清理多餘的 Error 類型（IAP 後）

**目標：** 評估 `SystemError`、`APIError`、`BusinessError`、`ParseError` 是否還有使用者。
S01 移除 APICallHelper 的 SystemError 注入後，直接 throw 的 14 個檔案（20 處）仍在。
確認都被 `toDomainError()` 的 `isCancellationError` 兜住後，可以逐步清理。

**Files：**
- `Havital/Havital/Services/Core/UnifiedAPIResponse.swift` — 定義處
- 20 處 `throw SystemError.taskCancelled`（14 個檔案）+ APICallHelper 2 處 `return`

**Verify：** Build 通過 + grep 確認無殘留引用

---

## 風險評估

### 1. S01 風險：移除 APICallHelper 包裝

**風險：** 20 處直接 `throw SystemError.taskCancelled`（跨 14 個檔案）不受 S01 影響，仍會產生 SystemError。
**緩解：** `toDomainError()` 的 `isCancellationError` 兜底已就位（DomainError.swift:150），能正確轉換。

### 2. S02 風險：統一 catch 模式時的行為回歸

**風險：** 5 個函式在取消時需要 `isLoadingAnimation = false`。
**緩解：** 模板分兩種（見 S02）。Developer 逐一比對。

### 3. S03 風險：@Observable 遷移

**風險 A：** `@Bindable` 判斷錯誤 → Sheet binding 壞掉（isLoadingAnimation, showWeeklySummary, paywallTrigger）。
**緩解：** 搜尋所有 `$viewModel.` 引用，這些必須用 `@Bindable`。

**風險 B：** DependencyContainer 的 `makeTrainingPlanV2ViewModel()` 可能回傳 protocol type，@Observable 需要 concrete type。
**緩解：** 檢查 factory method 回傳型別。

**風險 C：** `@Observable` class 不能有 `nonisolated let taskRegistry`。
**緩解：** [需驗證] @Observable macro 對 nonisolated let 的處理。如果衝突，taskRegistry 可以標記 `@ObservationIgnored`。

### 4. 最壞情況

S03 遷移後 Sheet binding 壞掉。
**修正成本：** 低。把 `var` 改成 `@Bindable` 即可。Build error 會指出。

## 不再需要的任務（被 S03 取代）

| 舊任務 | 為什麼不需要了 |
|--------|--------------|
| S05-C（initialize 取消恢復） | `task(id:)` 自動管理 cancel/restart |
| S06（detached 隔離） | @Observable 消除不必要的重繪，取消頻率大降 |
| S05-A/B（Track B 統一） | 結構性整理，不影響正確性，可獨立排期 |

## 執行順序

```
IAP 前（本週）：
  S01（砍 APICallHelper 包裝）
    ↓
  S02（統一 12 個 catch）
    ↓
  S03（@Observable 遷移）← 根治重繪問題

IAP 後：
  S04（其他 ViewModel catch 統一）
    ↓
  S05（清理多餘 Error 類型）
```

## 完整防禦層級

```
Layer 1 — S01: 砍多餘包裝      → 取消錯誤保留原始型別（不再丟失）
Layer 2 — S02: 統一 catch      → 取消被正確靜默（不再顯示錯誤）
Layer 3 — S03: @Observable     → 取消不再頻繁發生（根治重繪觸發源）
             + task(id:)       → initialize 自動管理生命週期
```

## Resume Point

S01 尚未開始。下一步：dispatch S01+S02+S03 給 Developer。
