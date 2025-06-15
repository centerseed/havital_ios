# WeekSelectorSheet 組件文檔

## 概述
`WeekSelectorSheet` 是一個用於選擇訓練週數的底部彈出式視圖組件。它提供了直觀的週數選擇界面，並支持從新到舊的週數排序顯示。

## 主要功能
1. 顯示可選擇的訓練週數列表
2. 支持週數從新到舊排序
3. 提供週數選擇的視覺反饋
4. 支持取消選擇操作

## 技術實現

### 數據結構
```swift
struct WeekSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedWeekIndex: Int
    let availableWeeks: [Int]
    let onWeekSelected: (Int) -> Void
}
```

### 主要屬性
- `dismiss`: 環境變量，用於關閉視圖
- `selectedWeekIndex`: 綁定變量，當前選中的週數索引
- `availableWeeks`: 可選擇的週數數組
- `onWeekSelected`: 週數選擇回調函數

### 視圖結構
1. 頂部標題欄
   - 顯示"選擇週數"標題
   - 包含關閉按鈕

2. 週數列表
   - 使用 `List` 顯示所有可用週數
   - 每個週數項包含：
     - 週數標籤（"第 X 週"）
     - 選中狀態指示器
   - 支持點擊選擇週數

3. 取消按鈕
   - 位於列表底部
   - 點擊後關閉視圖並重置選擇

### 交互邏輯
1. 週數選擇
   - 點擊週數項時更新 `selectedWeekIndex`
   - 觸發 `onWeekSelected` 回調
   - 自動關閉視圖

2. 取消操作
   - 點擊取消按鈕時關閉視圖
   - 不觸發週數選擇回調

3. 關閉操作
   - 點擊關閉按鈕時關閉視圖
   - 不觸發週數選擇回調

### 樣式設計
1. 導航欄樣式
   - 使用 `.navigationBarTitleDisplayMode(.inline)`
   - 標題居中顯示

2. 列表項樣式
   - 使用 `HStack` 實現水平佈局
   - 選中狀態使用 `Image(systemName: "checkmark")` 顯示
   - 選中項使用 `.foregroundColor(.blue)` 高亮顯示

3. 取消按鈕樣式
   - 使用 `.foregroundColor(.red)` 突出顯示
   - 置於列表底部

## 使用示例
```swift
WeekSelectorSheet(
    selectedWeekIndex: $selectedWeekIndex,
    availableWeeks: [1, 2, 3, 4],
    onWeekSelected: { weekIndex in
        // 處理週數選擇
    }
)
```

## 注意事項
1. 確保 `availableWeeks` 數組不為空
2. 週數索引從 1 開始
3. 視圖會自動處理關閉操作
4. 選擇週數後會自動關閉視圖

## 相關組件
- `TrainingPlanView`: 使用此組件進行週數選擇
- `TrainingPlanViewModel`: 提供週數數據和選擇邏輯

## 更新歷史
- 初始版本：實現基本週數選擇功能
- 當前版本：支持從新到舊排序顯示 