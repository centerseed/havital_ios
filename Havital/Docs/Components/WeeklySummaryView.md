# WeeklySummaryView

## 概述
`WeeklySummaryView` 是週摘要的視圖組件，用於顯示每週訓練的總結信息。

## 主要功能
1. 顯示週訓練總結
2. 展示訓練數據統計
3. 提供訓練反饋

## 技術實現

### 數據結構
```swift
struct WeeklySummaryView: View {
    let summary: WeeklySummary
    @Environment(\.dismiss) private var dismiss
}
```

### 視圖結構
1. 頂部信息
   - 顯示週數
   - 顯示訓練日期範圍

2. 訓練數據
   - 顯示完成情況
   - 顯示訓練時長
   - 顯示訓練強度

3. 訓練反饋
   - 顯示教練建議
   - 顯示下週計劃

## 使用示例
```swift
WeeklySummaryView(summary: weeklySummary)
```

## 注意事項
1. 確保數據完整性
2. 處理空數據情況
3. 提供適當的用戶反饋

## 相關組件
- `TrainingPlanView`: 使用此組件顯示週摘要
- `WeeklySummary`: 週摘要數據模型

## 更新歷史
- 初始版本：基本週摘要顯示
- 當前版本：優化數據展示和交互 