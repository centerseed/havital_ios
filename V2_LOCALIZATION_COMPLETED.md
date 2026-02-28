# TrainingPlanV2 本地化修復完成報告

## ✅ 已完成的工作

### 1. 新增本地化字串到 zh-Hant.lproj/Localizable.strings

新增了 **90 個**本地化字串，涵蓋：
- TrainingPlanV2View 相關字串（24 個）
- WeeklySummaryV2View 相關字串（1 個）
- PlanOverviewSheetV2 相關字串（27 個）
- WeekTimelineViewV2 相關字串（17 個）
- ExercisesListView 相關字串（5 個）
- SupplementaryTrainingView 相關字串（16 個）

### 2. 修改程式碼使用 NSLocalizedString()

已完成所有 6 個檔案的修改，將硬編碼字串替換為本地化調用：

#### ✅ PlanOverviewSheetV2.swift
**修改數量**: ~20 處
- Tab 標題
- 目標卡片欄位
- 方法論、策略、階段標題
- 訓練類型對照函式

#### ✅ TrainingPlanV2View.swift
**修改數量**: ~20 處
- 選單項目
- 狀態提示視圖
- 產生下週課表相關訊息
- Alert 對話框

#### ✅ WeekTimelineViewV2.swift
**修改數量**: ~15 處
- 已完成訓練標籤
- 暖身/緩和標籤
- 間歇訓練類型對照函式
- 訓練段落標籤

#### ✅ SupplementaryTrainingView.swift
**修改數量**: ~15 處
- 補充訓練標題
- 力量訓練類型對照函式（7 種）
- 交叉訓練類型對照函式（6 種）
- 時間單位

#### ✅ ExercisesListView.swift
**修改數量**: 5 處
- 訓練動作標題
- 組數、次數、秒數單位

#### ✅ WarmupCooldownView.swift
**修改數量**: 2 處
- 暖身/緩和標籤

---

## 📊 統計

- **新增本地化字串**: ~90 個
- **修改的檔案**: 6 個
- **實際修改行數**: ~80 行
- **涵蓋模組**: TrainingPlanV2 完整流程

---

## ⚠️ 後續待辦事項

### 1. 更新其他語言版本（必須）

需要將相同的字串添加到：
- ⏳ `Havital/Resources/en.lproj/Localizable.strings`
- ⏳ `Havital/Resources/ja.lproj/Localizable.strings`

**參考檔案**: `v2_missing_localizations.txt`

### 2. 編譯測試

```bash
cd /Users/wubaizong/havital/apps/ios/Havital
xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 16'
```

### 3. UI 測試

- [ ] 切換系統語言到英文，檢查所有 V2 UI 畫面
- [ ] 切換系統語言到日文，檢查所有 V2 UI 畫面
- [ ] 確認沒有顯示 key 值（如 `training.race_info`）
- [ ] 確認所有按鈕、標題、提示訊息都正常顯示

---

## 📝 修改摘要

### 關鍵修改模式

1. **簡單字串替換**
   ```swift
   // Before
   Text("賽事資訊")

   // After
   Text(NSLocalizedString("training.race_info", comment: "Race Info"))
   ```

2. **帶參數的字串格式化**
   ```swift
   // Before
   Text("產生第 \(weekNumber) 週課表")

   // After
   Text(String(format: NSLocalizedString("training.generate_week_n_plan", comment: "Generate Week N Plan"), weekNumber))
   ```

3. **函式返回值本地化**
   ```swift
   // Before
   private func formatWorkoutType(_ type: String) -> String {
       let mapping: [String: String] = [
           "short_interval": "短間歇",
           ...
       ]
       return mapping[type] ?? type
   }

   // After
   private func formatWorkoutType(_ type: String) -> String {
       switch type {
       case "short_interval":
           return NSLocalizedString("training.workout_type.short_interval", comment: "Short Interval")
       ...
       }
   }
   ```

---

## 🔍 驗證清單

- [x] 所有硬編碼中文字串已替換為 NSLocalizedString()
- [x] 所有本地化字串已添加到 zh-Hant.lproj/Localizable.strings
- [ ] 英文本地化字串已添加到 en.lproj/Localizable.strings
- [ ] 日文本地化字串已添加到 ja.lproj/Localizable.strings
- [ ] 編譯測試通過
- [ ] UI 測試（繁體中文）通過
- [ ] UI 測試（英文）通過
- [ ] UI 測試（日文）通過

---

## 🎯 下一步

1. **立即**: 將 `v2_missing_localizations.txt` 中的字串翻譯成英文和日文
2. **立即**: 執行編譯測試確保沒有語法錯誤
3. **建議**: 在實機或模擬器上測試所有 V2 UI 流程

---

完成日期: 2026-02-16
修改者: Claude Code Assistant
