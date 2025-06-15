# TrainingPlanViewModel

## 概述
`TrainingPlanViewModel` 是訓練計劃的視圖模型，負責處理訓練計劃的業務邏輯和數據管理。

## 主要功能
1. 管理訓練計劃數據
2. 處理訓練進度更新
3. 管理週摘要數據
4. 處理數據緩存

## 技術實現

### 數據結構
```swift
class TrainingPlanViewModel: ObservableObject {
    @Published var weeklyPlan: WeeklyPlan?
    @Published var planStatus: PlanStatus = .loading
    @Published var weeklySummaries: [WeeklySummary] = []
    @Published var selectedWeekIndex: Int = 1
}
```

### 主要方法
1. 數據加載
   - `loadWeeklyPlan()`
   - `fetchWeeklySummaries()`
   - `forceUpdateWeeklySummaries()`

2. 緩存管理
   - `cacheWeeklyPlan()`
   - `loadCachedWeeklyPlan()`
   - `cacheWeeklySummaries()`
   - `loadCachedWeeklySummaries()`

3. 訓練進度管理
   - `updateTrainingProgress()`
   - `handleTrainingCompletion()`

## 使用示例
```swift
let viewModel = TrainingPlanViewModel()
viewModel.loadWeeklyPlan()
```

## 注意事項
1. 確保正確處理異步操作
2. 實現適當的錯誤處理
3. 維護數據一致性

## 相關組件
- `TrainingPlanView`: 使用此 ViewModel
- `WeeklyPlan`: 訓練計劃數據模型
- `WeeklySummary`: 週摘要數據模型

## 更新歷史
- 初始版本：基本數據管理
- 當前版本：支持緩存和優化加載 