# TrainingPlanView

## 概述
`TrainingPlanView` 是訓練計劃的主要視圖組件，負責顯示和管理用戶的訓練計劃。

## 主要功能
1. 顯示訓練計劃內容
2. 管理訓練進度
3. 處理訓練計劃的加載和更新
4. 提供訓練計劃的交互功能

## 技術實現

### 數據結構
```swift
struct TrainingPlanView: View {
    @StateObject private var viewModel: TrainingPlanViewModel
    @State private var showingWeekSelector = false
    @State private var selectedWeekIndex: Int = 1
}
```

### 視圖結構
1. 頂部導航欄
   - 顯示當前週數
   - 提供週數選擇按鈕

2. 訓練計劃內容
   - 使用 `ScrollView` 顯示訓練內容
   - 包含訓練日卡片
   - 顯示訓練進度

3. 底部操作欄
   - 提供訓練相關操作按鈕
   - 顯示訓練狀態

### 狀態管理
1. 加載狀態
   - 使用 `ZStack` 處理加載狀態
   - 提供加載動畫
   - 支持緩存數據顯示

2. 錯誤處理
   - 顯示錯誤信息
   - 提供重試選項

## 使用示例
```swift
TrainingPlanView()
    .environmentObject(TrainingPlanViewModel())
```

## 注意事項
1. 需要正確配置 ViewModel
2. 處理網絡錯誤和加載狀態
3. 確保數據緩存機制正常運作

## 相關組件
- `WeekSelectorSheet`: 用於選擇週數
- `TrainingDayCard`: 顯示單日訓練內容
- `TrainingProgressView`: 顯示訓練進度

## 更新歷史
- 初始版本：基本訓練計劃顯示
- 當前版本：支持緩存和優化加載體驗 