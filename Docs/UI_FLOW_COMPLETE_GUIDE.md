# Paceriz iOS 訓練計畫 UI 調用流程完整說明

## 一、View 層級結構

```
TrainingPlanView (主畫面)
├── @StateObject viewModel: TrainingPlanViewModel
│   ├── weeklyPlanVM: WeeklyPlanViewModel (@Published)
│   └── summaryVM: WeeklySummaryViewModel (@Published)
│
├── 主內容區域
│   ├── TrainingProgressCard (訓練進度卡片)
│   ├── WeekOverviewCard (週總覽卡片)
│   └── WeekTimelineView (週時間軸)
│       └── 使用 viewModel.getDateForDay(dayIndex:)
│           └── 內部讀取 viewModel.selectedWeek
│               └── 實際來自 weeklyPlanVM.selectedWeek
│
└── Sheets (彈出視窗層)
    ├── .sheet(isPresented: $showWeekSelector)
    │   └── WeekSelectorSheet
    │       ├── 查看課表按鈕 → fetchWeekPlan(week:)
    │       └── 查看週回顧按鈕 → fetchWeeklySummary(weekNumber:)
    │
    ├── .sheet(isPresented: viewModel.showWeeklySummary)
    │   └── WeeklySummaryView (週回顧內容)
    │
    ├── .sheet(isPresented: viewModel.showAdjustmentConfirmation)
    │   └── AdjustmentConfirmationView (調整確認)
    │
    └── .sheet(isPresented: $viewModel.isLoadingAnimation)
        └── LoadingAnimationView (載入動畫)
```

## 二、ViewModel 結構與職責

```
TrainingPlanViewModel (組合者/協調者)
│
├── 子 ViewModels
│   ├── weeklyPlanVM: WeeklyPlanViewModel
│   │   ├── selectedWeek: Int (使用者選擇的週數)
│   │   ├── currentWeek: Int (實際當前週數)
│   │   ├── state: ViewState<WeeklyPlan> (週計畫狀態)
│   │   └── overviewState: ViewState<TrainingPlanOverview> (總覽狀態)
│   │
│   └── summaryVM: WeeklySummaryViewModel
│       ├── summaryState: ViewState<WeeklyTrainingSummary>
│       ├── showSummarySheet: Bool
│       └── showAdjustmentConfirmation: Bool
│
├── 自身狀態
│   ├── planStatus: PlanStatus (.loading/.ready/.noPlan/.error)
│   ├── workoutsByDayV2: [Int: [WorkoutV2]] (訓練記錄)
│   └── isLoadingAnimation: Bool
│
└── 計算屬性 (Proxy)
    ├── selectedWeek → weeklyPlanVM.selectedWeek
    ├── weeklyPlan → weeklyPlanVM.weeklyPlan
    ├── trainingOverview → weeklyPlanVM.overviewState.data
    ├── showWeeklySummary → summaryVM.showSummarySheet
    └── weeklySummary → summaryVM.summaryState.data
```

## 三、關鍵問題：SwiftUI 嵌套 ObservableObject

### 問題根源

```swift
@MainActor
class TrainingPlanViewModel: ObservableObject {
    @Published var weeklyPlanVM: WeeklyPlanViewModel  // ❌ 只觀察引用變更
}
```

**SwiftUI 的限制**：
- `@Published var weeklyPlanVM` 只在 `weeklyPlanVM` **本身**被替換時觸發更新
- 當 `weeklyPlanVM.selectedWeek` 變更時，SwiftUI **不會自動**重新渲染 TrainingPlanView
- 這就是為什麼日期不更新的根本原因！

### 解決方案：手動轉發變更通知

```swift
// 在 TrainingPlanViewModel.setupBindings() 中
weeklyPlanVM.$selectedWeek
    .receive(on: DispatchQueue.main)
    .sink { [weak self] newWeek in
        self?.objectWillChange.send()  // ✅ 手動觸發更新
    }
    .store(in: &cancellables)
```

## 四、完整的數據流向

### 4.1 初始化流程

```
App 啟動
    ↓
TrainingPlanView.task { await viewModel.initialize() }
    ↓
TrainingPlanViewModel.initialize()
    ↓
├── loadPlanStatus(shouldResetSelectedWeek: true)
│   ├── API: GET /v2/plan/status
│   ├── weeklyPlanVM.currentWeek = status.currentWeek
│   └── weeklyPlanVM.selectedWeek = status.currentWeek  // 初始設置
│
├── weeklyPlanVM.loadOverview()
│   └── API: GET /v2/plan/overview
│       └── overviewState = .loaded(overview)
│
├── weeklyPlanVM.loadWeeklyPlan()
│   └── API: GET /v2/plan/{overviewId}_{selectedWeek}
│       └── state = .loaded(plan)
│
├── loadWorkoutsForCurrentWeek()
│   ├── 計算週日期範圍：
│   │   overview.createdAt + selectedWeek → [週一...週日]
│   └── 從 Repository 載入該週的 workouts
│       └── workoutsByDayV2 = [dayIndex: [workouts]]
│
└── updatePlanStatus(from: weeklyPlanVM.state)
    └── planStatus = .ready(plan)  // ✅ UI 顯示課表
```

### 4.2 切換週數流程（從 WeekSelectorSheet）

```
用戶點擊「查看課表」(Week 2)
    ↓
WeekSelectorSheet.Button {
    Task {
        viewModel.selectedWeek = 2  // ✅ 設置選擇週數
        await viewModel.fetchWeekPlan(week: 2)
        isPresented = false  // 關閉 sheet
    }
}
    ↓
TrainingPlanViewModel.fetchWeekPlan(week: 2)
    ↓
├── planStatus = .loading  // 顯示載入中
│
├── weeklyPlanVM.selectWeek(2)
│   ├── selectedWeek = 2  // ✅ 更新週數
│   │   └── 觸發 Combine 訂閱
│   │       └── TrainingPlanVM.objectWillChange.send()  // ✅ 通知 UI
│   │
│   └── loadWeeklyPlan()
│       └── API: GET /v2/plan/{overviewId}_2
│           └── state = .loaded(plan)
│
├── loadWorkoutsForCurrentWeek()
│   ├── 使用 selectedWeek = 2 計算日期範圍
│   │   overview.createdAt + week 2 → [第二週的週一...週日]
│   └── workoutsByDayV2 = [第二週的 workouts]
│
└── updatePlanStatus(from: weeklyPlanVM.state)
    └── planStatus = .ready(plan)
```

### 4.3 日期計算流程（關鍵！）

```
WeekTimelineView 渲染
    ↓
ForEach(plan.days) { day in
    if let date = viewModel.getDateForDay(dayIndex: day.dayIndexInt)
}
    ↓
TrainingPlanViewModel.getDateForDay(dayIndex: 2)  // 週二
    ↓
├── 讀取 trainingOverview (來自 weeklyPlanVM.overviewState.data)
├── 讀取 selectedWeek (來自 weeklyPlanVM.selectedWeek)  // ✅ 這裡！
│
└── WeekDateService.weekDateInfo(
        createdAt: overview.createdAt,  // 計畫起始日期
        weekNumber: selectedWeek        // 使用者選擇的週數
    )
    ↓
計算邏輯：
    1. 解析 createdAt → 2025-01-15 (假設)
    2. 計算該日期的週一 → 2025-01-13
    3. 加上 (selectedWeek - 1) * 7 天
       - Week 1: 2025-01-13
       - Week 2: 2025-01-20  // ✅ 正確！
    4. daysMap[2] = 週一 + 1天 = 2025-01-21 (週二)
```

### 4.4 查看週回顧流程

```
用戶點擊「查看週回顧」(Week 1)
    ↓
WeekSelectorSheet.Button {
    Task {
        await viewModel.fetchWeeklySummary(weekNumber: 1)
        isPresented = false  // ✅ 等 API 完成後才關閉
    }
}
    ↓
TrainingPlanViewModel.fetchWeeklySummary(weekNumber: 1)
    ↓
summaryVM.loadWeeklySummary(weekNumber: 1)
    ↓
├── summaryState = .loading
│
├── API: GET /summary/run_race/week/1
│   └── 返回已存在的週回顧
│
├── summaryState = .loaded(summary)
│
└── showSummarySheet = true  // ✅ 顯示 sheet
    ↓
TrainingPlanView 監聽到 showWeeklySummary 變更
    ↓
.sheet(isPresented: viewModel.showWeeklySummary) {
    WeeklySummaryView(summary: viewModel.weeklySummary)
}
```

### 4.5 產生下週課表流程

```
用戶點擊「產生下週課表」
    ↓
TrainingPlanViewModel.generateNextWeekPlan(targetWeek: 2)
    ↓
├── isLoadingAnimation = true  // 顯示載入動畫
│
├── weeklyPlanVM.selectedWeek = 2  // ⭐ 先設置選擇週數
│   └── 觸發 Combine 訂閱 → objectWillChange.send()
│
├── weeklyPlanVM.generateWeeklyPlan(targetWeek: 2)
│   └── API: POST /v2/plan/week
│       └── state = .loaded(新課表)
│
├── loadPlanStatus(skipCache: true, shouldResetSelectedWeek: false)
│   ├── API: GET /v2/plan/status
│   ├── weeklyPlanVM.currentWeek = 2
│   └── 保留 selectedWeek = 2（不重置）
│
├── loadWorkoutsForCurrentWeek()
│   └── 使用 selectedWeek = 2 計算日期
│
├── updatePlanStatus(from: weeklyPlanVM.state)
│   └── planStatus = .ready(新課表)
│
└── isLoadingAnimation = false  // 關閉動畫
```

## 五、Sheet 顯示優先級與互斥邏輯

```
SwiftUI Sheet 規則：同一時間只能顯示一個 sheet

TrainingPlanView 的 Sheet 順序（從上到下）：
1. .sheet(isPresented: $showWeekSelector)         // 週選擇器
2. .sheet(isPresented: $showUserProfile)          // 用戶資料
3. .sheet(isPresented: $viewModel.isLoadingAnimation)  // 載入動畫
4. .sheet(isPresented: $showTrainingOverview)     // 訓練總覽
5. .sheet(isPresented: $showTrainingProgress)     // 訓練進度
6. .sheet(isPresented: $showShareSheet)           // 分享
7. .sheet(item: $editViewModel)                   // 編輯課表
8. .sheet(isPresented: viewModel.showAdjustmentConfirmation)  // 調整確認
9. .sheet(isPresented: viewModel.showWeeklySummary)  // 週回顧 ⭐

執行流程：
1. 用戶點擊「查看週回顧」
2. fetchWeeklySummary() 執行（非同步）
3. isPresented = false（關閉 WeekSelectorSheet）
4. summaryVM.showSummarySheet = true（開啟週回顧 sheet）
5. SwiftUI 先關閉 WeekSelectorSheet，再開啟 WeeklySummaryView
```

## 六、問題根源總結

### 之前的問題

1. **日期不更新**
   - 原因：selectedWeek 變更沒有觸發 UI 重新渲染
   - 修復：添加 Combine 訂閱轉發 objectWillChange

2. **週回顧點擊無反應**
   - 原因：isPresented = false 在 API 完成前就執行了
   - 修復：將 isPresented = false 移到 await 之後

3. **使用錯誤的 API**
   - 原因：用 createWeeklySummary (POST) 載入已存在的週回顧
   - 修復：新增 loadWeeklySummary 使用 GET API

### 當前架構的複雜性來源

1. **嵌套 ObservableObject**
   - TrainingPlanViewModel 包含 weeklyPlanVM 和 summaryVM
   - 需要手動轉發內部變更通知

2. **多層代理屬性**
   - viewModel.selectedWeek → weeklyPlanVM.selectedWeek
   - viewModel.weeklySummary → summaryVM.summaryState.data

3. **多個 Sheet 管理**
   - 9 個不同的 sheet，需要協調顯示時機

4. **非同步操作協調**
   - API 調用、狀態更新、UI 刷新的時序控制

## 七、建議的改進方向（未來）

### Option 1: 扁平化 ViewModel (推薦)

```swift
@MainActor
class TrainingPlanViewModel: ObservableObject {
    // 移除嵌套，直接管理所有狀態
    @Published var selectedWeek: Int = 1
    @Published var weeklyPlanState: ViewState<WeeklyPlan> = .loading
    @Published var summaryState: ViewState<WeeklyTrainingSummary> = .empty

    // 使用 Repository，不需要子 ViewModel
    private let planRepository: TrainingPlanRepository
}
```

**優點**：
- 消除嵌套 ObservableObject 問題
- 不需要手動轉發變更通知
- 狀態管理更直觀

**缺點**：
- 需要大規模重構
- 破壞現有的模組化結構

### Option 2: 拆分成獨立 View

```swift
// 週計畫頁面
WeeklyPlanView(viewModel: WeeklyPlanViewModel())

// 週回顧頁面
WeeklySummaryView(viewModel: WeeklySummaryViewModel())

// 不再組合，各自獨立
```

**優點**：
- 完全解耦，各自獨立
- 符合單一職責原則

**缺點**：
- 失去統一的協調點
- 需要其他機制共享狀態（如 selectedWeek）

### Option 3: 保持現狀 + Combine 轉發 (當前方案)

**優點**：
- 最小改動
- 保持現有架構
- Clean Architecture 結構完整

**缺點**：
- 需要手動管理轉發邏輯
- 複雜度較高

## 八、關鍵修復點索引

1. **日期計算使用 selectedWeek**
   - [TrainingPlanViewModel.swift:114](../Havital/Features/TrainingPlan/Presentation/ViewModels/TrainingPlanViewModel.swift#L114)

2. **Combine 訂閱轉發 selectedWeek 變更**
   - [TrainingPlanViewModel.swift:432-442](../Havital/Features/TrainingPlan/Presentation/ViewModels/TrainingPlanViewModel.swift#L432-L442)

3. **WeekSelectorSheet 非同步執行順序**
   - [WeekSelectorSheet.swift:76-80](../Havital/Views/Training/Components/WeekSelectorSheet.swift#L76-L80)

4. **載入已存在週回顧的新方法**
   - [WeeklySummaryViewModel.swift:110-140](../Havital/Features/TrainingPlan/Presentation/ViewModels/WeeklySummaryViewModel.swift#L110-L140)

5. **產生週課表時先設置 selectedWeek**
   - [TrainingPlanViewModel.swift:849](../Havital/Features/TrainingPlan/Presentation/ViewModels/TrainingPlanViewModel.swift#L849)
