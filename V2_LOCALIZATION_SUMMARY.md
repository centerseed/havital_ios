# TrainingPlanV2 本地化修復摘要

## ✅ 已完成

### 1. 已添加到 zh-Hant.lproj/Localizable.strings

已新增 **90+ 個**本地化字串，涵蓋以下模組：

#### **TrainingPlanV2View** (24 個字串)
- 導航和按鈕：返回本週、本週/非本週標記、週摘要等
- 狀態提示：無計畫、需要週回顧、訓練完成等
- 產生下週課表相關訊息

#### **WeeklySummaryV2View** (1 個字串)
- 接受調整並產生下週課表按鈕

#### **PlanOverviewSheetV2** (27 個字串)
- Tab 標題：賽事資訊、訓練計畫
- 目標卡片：賽事日期、距離、配速、時間等
- 訓練計畫：方法論、策略、重點、里程碑
- 訓練類型對照：8 種訓練類型

#### **WeekTimelineViewV2** (17 個字串)
- 訓練狀態：已完成訓練、更多訓練
- 暖身/緩和標籤
- 間歇訓練類型：9 種類型
- 間歇訓練段落標籤

#### **ExercisesListView** (5 個字串)
- 訓練動作、組、次、秒等單位

#### **SupplementaryTrainingView** (16 個字串)
- 補充訓練標題
- 力量訓練類型：7 種
- 交叉訓練類型：6 種

---

## ⚠️ 待辦事項

### 1. 更新其他語言版本

需要將相同的字串添加到：
- ✅ `Havital/Resources/zh-Hant.lproj/Localizable.strings` (已完成)
- ⏳ `Havital/Resources/en.lproj/Localizable.strings` (待完成)
- ⏳ `Havital/Resources/ja.lproj/Localizable.strings` (待完成)

### 2. 修改程式碼使用 NSLocalizedString

需要在以下檔案中將硬編碼字串替換為 NSLocalizedString() 調用：

#### **高優先級 (大量硬編碼)**
1. `PlanOverviewSheetV2.swift` - **幾乎全部硬編碼**
   - Line 22, 24, 63, 137, 142, 155, 170, 185, 200, 225, 243 等
   - Line 306, 319, 331, 350, 366, 435, 451, 470, 505
   - Line 578-585 (訓練類型對照函式)

2. `TrainingPlanV2View.swift` - **約 20 處硬編碼**
   - Line 162, 166, 178 (選單項目)
   - Line 412, 416, 439, 443, 456 (狀態提示)
   - Line 480, 484, 503, 513, 520, 527, 540, 551, 572, 583

#### **中優先級**
3. `WeekTimelineViewV2.swift`
   - Line 215 (已完成訓練)
   - Line 594-619 (訓練類型對照函式)

4. `SupplementaryTrainingView.swift`
   - Line 14 (補充訓練)
   - Line 64, 119 (分鐘單位)
   - Line 84-103 (力量訓練類型函式)
   - Line 132-141 (交叉訓練類型函式)

#### **低優先級**
5. `ExercisesListView.swift`
   - Line 14, 56, 62, 69 (單位)

6. `WarmupCooldownView.swift`
   - Line 29, 30 (暖身/緩和)

---

## 📝 修改範例

### 修改前 (硬編碼)
```swift
Text("賽事資訊")
    .tag(0)
```

### 修改後 (使用本地化)
```swift
Text(NSLocalizedString("training.race_info", comment: "Race Info"))
    .tag(0)
```

### 批次替換範例 (PlanOverviewSheetV2.swift)

```swift
// Line 22
Text(viewModel.planOverview?.isRaceRunTarget == true
    ? NSLocalizedString("training.race_info", comment: "Race Info")
    : NSLocalizedString("training.target_info", comment: "Target Info"))
    .tag(0)

// Line 24
Text(NSLocalizedString("training.training_plan", comment: "Training Plan"))
    .tag(1)

// Line 137
Text(overview.isRaceRunTarget
    ? NSLocalizedString("training.target_race", comment: "Target Race")
    : NSLocalizedString("training.training_target", comment: "Training Target"))
    .font(AppFont.headline())
```

---

## 🔍 驗證步驟

完成修改後，請執行以下驗證：

1. **編譯測試**
   ```bash
   cd /Users/wubaizong/havital/apps/ios/Havital
   xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 16'
   ```

2. **搜尋殘留硬編碼**
   ```bash
   # 搜尋 TrainingPlanV2 相關檔案中的中文字串
   grep -r "[\u4e00-\u9fff]" Havital/Features/TrainingPlanV2/Presentation/Views/ --include="*.swift"
   ```

3. **UI 測試**
   - 切換系統語言到英文/日文
   - 檢查所有 V2 UI 畫面是否正常顯示本地化文字
   - 確認沒有顯示 key 值（如 `training.race_info`）

---

## 📊 統計

- **新增本地化字串**: ~90 個
- **需要修改的檔案**: 6 個
- **預計修改行數**: ~150 行
- **涵蓋模組**: TrainingPlanV2 完整流程

---

## 🔗 相關檔案

- 缺失字串清單: `v2_missing_localizations.txt`
- 修改摘要: 本文件 `V2_LOCALIZATION_SUMMARY.md`
- 本地化檔案:
  - `Havital/Resources/zh-Hant.lproj/Localizable.strings` ✅
  - `Havital/Resources/en.lproj/Localizable.strings` ⏳
  - `Havital/Resources/ja.lproj/Localizable.strings` ⏳
