# 編輯週課表 - 流程設計

## 概述

編輯週課表功能讓用戶可以調整每週的訓練計劃，包括更改訓練類型、調整距離和配速、重新安排訓練日等。

---

## 一、頁面架構

```
EditScheduleView (主頁面)
├── 7 張 SimplifiedDailyCard (訓練卡片)
│   ├── 訓練類型 Menu (切換類型)
│   ├── TrainingDetailsEditView (顯示/編輯詳情)
│   └── 詳細編輯按鈕 → TrainingEditSheet
│       └── TrainingDetailEditor (根據類型顯示不同編輯器)
│           ├── EasyRunDetailEditor
│           ├── TempoRunDetailEditor
│           ├── IntervalDetailEditor
│           ├── CombinationDetailEditor ⭐
│           ├── LongRunDetailEditor
│           └── SimpleTrainingDetailEditor
└── 儲存按鈕 → API 更新
```

---

## 二、主頁面 EditScheduleView

### 顯示內容
- 7 張訓練卡片，按周一到周日排列
- 每張卡片顯示：日期、訓練類型、距離/配速摘要
- 支援拖拽排序（調換不同天的訓練內容）

### 操作流程
1. **拖拽排序** - 長按卡片，拖拽到新位置
2. **切換訓練類型** - 點擊訓練類型標籤，彈出 Menu 選擇新類型
3. **快速編輯** - 點擊配速/距離標籤，直接彈出 Picker 編輯
4. **詳細編輯** - 點擊右側按鈕，進入詳細編輯頁面
5. **儲存** - 點擊儲存按鈕，上傳修改到後端

---

## 三、訓練卡片 SimplifiedDailyCard

### 卡片結構
```
┌─────────────────────────────────────────┐
│ 周一 12/2     [10.0 km]  [⚙️] │   [節奏跑 ▼] │  ← 頂部：日期、距離、編輯按鈕類型 Menu
├─────────────────────────────────────────   [=] ← 調整順序  ┤
│ 配速: 5:00  距離: 10.0km            ← 底部：詳情 
└─────────────────────────────────────────┘
```

### 各類型卡片顯示

| 訓練類型 | 卡片底部顯示 | 可直接編輯 |
|---------|-------------|-----------|
| 輕鬆跑/恢復跑 | `距離: 5.0km` | ✅ 距離 |
| 節奏跑/閾值跑 | `配速: 5:00  距離: 8.0km` | ✅ 配速、距離 |
| 間歇跑 | `4× 400m @ 4:30` | ✅ 次數、距離、配速 |
| 組合跑/漸進跑 | `[段1] [段2] [段3]` 摘要 | ❌ 需進入詳細頁 |
| 長跑 | `距離: 20.0km` | ✅ 距離 |
| 休息日 | (無底部區域) | - |

### 點擊行為

| 點擊位置 | 行為 |
|---------|------|
| 訓練類型標籤 | 彈出 Menu，選擇新類型 |
| 配速/距離標籤 | 彈出對應的 Wheel Picker |
| 右側 ⚙️ 按鈕 | 進入詳細編輯頁面 |
| 卡片其他區域 | 無反應（避免誤觸） |

---

## 四、詳細編輯頁 TrainingDetailEditor

### 4.1 輕鬆跑/恢復跑 (EasyRunDetailEditor)

```
┌─────────────────────────────────────┐
│ 輕鬆跑設定                           │
├─────────────────────────────────────┤
│ 💡 建議配速: 6:00 /km    [套用]     │
│    配速區間: 5:45 ~ 6:15            │
├─────────────────────────────────────┤
│ 距離                                 │
│ [  5.0 km  ▼]                       │
├─────────────────────────────────────┤
│ 說明                                 │
│ 輕鬆跑，保持舒適的節奏              │
└─────────────────────────────────────┘
```

**可編輯項目：**
- 距離 (DistancePickerField)

---

### 4.2 節奏跑/閾值跑 (TempoRunDetailEditor)

```
┌─────────────────────────────────────┐
│ 節奏跑設定                           │
├─────────────────────────────────────┤
│ 💡 建議配速: 5:00 /km    [套用]     │
│    配速區間: 4:50 ~ 5:10            │
├─────────────────────────────────────┤
│     配速             距離            │
│ [  5:00  ▼]     [  8.0 km  ▼]      │
├─────────────────────────────────────┤
│ 說明                                 │
│ 維持穩定的中高強度配速              │
└─────────────────────────────────────┘
```

**可編輯項目：**
- 距離 (DistancePickerField)
- 配速 (PacePickerField)

---

### 4.3 間歇跑 (IntervalDetailEditor)

```
┌─────────────────────────────────────┐
│ 間歇訓練設定                         │
├─────────────────────────────────────┤
│ 快速選擇                             │
│ [400m×8] [400m×10] [800m×5] ...    │
├─────────────────────────────────────┤
│ 💡 建議配速: 4:30 /km    [套用]     │
├─────────────────────────────────────┤
│ 重複次數                             │
│ [  4 ×  ▼]                          │
├─────────────────────────────────────┤
│ 🔴 衝刺段                            │
│ 配速             距離               │
│ [  4:30  ▼]     [  400m  ▼]        │
├─────────────────────────────────────┤
│ 🔵 恢復段                            │
│ [✓] 原地休息                        │
│ 或                                   │
│ 配速               距離              │
│ [  6:00  ▼]       [  200m  ▼]      │
└─────────────────────────────────────┘
```

**可編輯項目：**
- 重複次數 (RepeatsPickerField)
- 衝刺段距離 (IntervalDistancePickerField)
- 衝刺段配速 (PacePickerField)
- 恢復段類型 (Toggle: 原地休息/跑步恢復)
- 恢復段距離 (IntervalDistancePickerField)
- 恢復段配速 (PacePickerField)

---

### 4.4 組合跑/漸進跑 (CombinationDetailEditor) ⭐ 重點

```
┌─────────────────────────────────────┐
│ 組合訓練設定                         │
├─────────────────────────────────────┤
│ 🟠 第 1 段                    [🗑️]  │
│ 描述: 熱身                           │
│ 配速             距離                │
│ [  2.0 km  ▼]    [  6:00  ▼]       │
├─────────────────────────────────────┤
│ 🟠 第 2 段                    [🗑️]  │
│ 描述: 節奏跑                         │
│ 配速             距離              │
│[  5:00  ▼]      [  5.0 km  ▼]    │
├─────────────────────────────────────┤
│ 🟠 第 3 段                    [🗑️]  │
│ 描述: 收操                           │
│ 配速             距離                │
│ [  6:30  ▼]     [  2.0 km  ▼]     │
├─────────────────────────────────────┤
│           [+ 新增分段]               │
├─────────────────────────────────────┤
│ 總距離: 9.0 km                      │
└─────────────────────────────────────┘
```

**可編輯項目：**
- 每段距離 (DistancePickerField)
- 每段配速 (PacePickerField)
- 每段描述 (可選，目前為只讀)
- **新增分段** ← 需要實現
- **刪除分段** ← 需要實現

**新增分段邏輯：**
```swift
func addSegment() {
    var updatedDay = editedDay
    if var details = updatedDay.trainingDetails {
        var segments = details.segments ?? []
        segments.append(MutableProgressionSegment(
            distanceKm: 2.0,
            pace: "5:30",
            description: "新分段"
        ))
        details.segments = segments
        details.totalDistanceKm = segments.compactMap { $0.distanceKm }.reduce(0, +)
        updatedDay.trainingDetails = details
    }
    editedDay = updatedDay
}
```

**刪除分段邏輯：**
```swift
func deleteSegment(at index: Int) {
    var updatedDay = editedDay
    if var details = updatedDay.trainingDetails {
        var segments = details.segments ?? []
        guard index < segments.count, segments.count > 1 else { return }
        segments.remove(at: index)
        details.segments = segments
        details.totalDistanceKm = segments.compactMap { $0.distanceKm }.reduce(0, +)
        updatedDay.trainingDetails = details
    }
    editedDay = updatedDay
}
```

---

### 4.5 長距離輕鬆跑 (LSD)

```
┌─────────────────────────────────────┐
│ LSD設定                             │
├─────────────────────────────────────┤
│ 距離                                 │
│ [  20.0 km  ▼]                      │
├─────────────────────────────────────┤
│ 說明                                 │
│ 長距離有氧耐力訓練                   │
└─────────────────────────────────────┘
```

**可編輯項目：**
- 距離 (DistancePickerField)

---

## 五、資料流

### 編輯流程

```
1. 進入 EditScheduleView
   ↓
2. 從 ViewModel.weeklyPlan 複製到 ViewModel.editingDays
   ↓
3. 用戶編輯 (直接修改 editingDays)
   ↓
4. 點擊儲存
   ↓
5. 將 editingDays 轉換為 WeeklyPlan
   ↓
6. 調用 API 更新
   ↓
7. 更新 ViewModel.weeklyPlan
   ↓
8. 關閉頁面
```

### Struct 值語義注意事項

由於 Swift Struct 是值類型，修改嵌套屬性時必須使用正確的模式：

```swift
// ❌ 錯誤 - 修改臨時副本，不會生效
day.trainingDetails?.distanceKm = newValue

// ✅ 正確 - 複製、修改、賦值回去
if var details = day.trainingDetails {
    details.distanceKm = newValue
    day.trainingDetails = details
}
```

---

## 六、待實現功能

### 優先級 1 (必須修復)
- [ ] 配速/距離點擊直接彈出 Picker (Button 需要 `.buttonStyle(.plain)`)
- [ ] 詳細頁面的配速/距離編輯生效

### 優先級 2 (核心功能)
- [ ] 組合跑新增分段功能
- [ ] 組合跑刪除分段功能

### 優先級 3 (體驗優化)
- [ ] 拖拽排序優化
- [ ] 編輯後即時顯示總距離變化
- [ ] 強度警告提示

---

## 七、檔案對應

| 功能 | 檔案 |
|------|------|
| 主頁面 | `EditScheduleView.swift` |
| 訓練卡片 | `EditScheduleView.swift` → `SimplifiedDailyCard` |
| 卡片內詳情顯示 | `EditableDailyCard.swift` → `TrainingDetailsEditView` |
| 詳細編輯頁 | `TrainingDetailEditor.swift` |
| Picker 元件 | `EditableDailyCard.swift` → `DistanceWheelPicker`, `PaceWheelPicker` 等 |
| 資料模型 | `EditScheduleView.swift` → `MutableTrainingDay`, `MutableTrainingDetails` |
