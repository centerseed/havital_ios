# Apple Watch App 單元測試和預測試指南

> 在真機測試前，通過單元測試、UI 預覽和模擬器測試發現問題

---

## 📋 測試層級

```
第1層: 單元測試（Unit Tests）        ⏱️ 1-2 分鐘
  ↓ 測試核心邏輯（配速、心率計算等）

第2層: SwiftUI Previews             ⏱️ 5-10 分鐘
  ↓ 測試 UI 佈局和樣式

第3層: 模擬器測試（模擬數據）        ⏱️ 10-15 分鐘
  ↓ 測試完整流程和互動

第4層: 真機測試                     ⏱️ 30-60 分鐘
  ↓ 測試 HealthKit、GPS 等硬體功能
```

---

## 🧪 第1層：單元測試（Unit Tests）

### 為什麼需要單元測試？

✅ **即時反饋** - 幾秒鐘內發現邏輯錯誤
✅ **自動化** - 每次修改代碼自動運行
✅ **覆蓋率** - 確保所有邊界情況都測試到
✅ **重構安全** - 修改代碼後確保功能不變

### 運行單元測試

#### Step 1: 在 Xcode 中運行

1. 打開 `Havital.xcodeproj`
2. 選擇 **Product** → **Test** (⌘U)
3. 查看測試結果（Test Navigator）

#### Step 2: 運行特定測試

```swift
// 只運行配速測試
⌘U on PaceFormatterTests class

// 只運行單個測試方法
⌘U on testPaceToSeconds_ValidPace()
```

### 已創建的測試套件

#### ✅ PaceFormatterTests（配速格式化）

測試內容：
- 配速字符串轉秒數（"5:30" → 330s）
- 秒數轉配速字符串（330s → "5:30"）
- 配速區間計算（目標 ± 20秒）
- 配速狀態判斷（理想/過快/過慢）

**運行命令**：
```bash
xcodebuild test -scheme Havital -only-testing:HavitalTests/PaceFormatterTests
```

**預期結果**：
```
✅ testPaceToSeconds_ValidPace
✅ testPaceToSeconds_InvalidPace
✅ testSecondsToPace
✅ testPaceRange
✅ testIsPaceInRange_Ideal
✅ testIsPaceInRange_TooFast
✅ testIsPaceInRange_TooSlow
```

#### ✅ TrainingTypeHelperTests（訓練類型判斷）

測試內容：
- 判斷是否是輕鬆課表（easy/recovery_run/lsd）
- 判斷是否是間歇訓練
- 判斷是否是組合跑
- 獲取訓練模式（心率/配速/間歇/組合）

#### ✅ HeartRateZoneDetectorTests（心率區間判斷）

測試內容：
- 根據當前心率判斷在哪個區間（Z1-Z5）
- 判斷心率狀態（在區間內/過高/過低）
- 邊界情況（剛好在區間邊緣）

#### ✅ SegmentTrackerTests（分段追蹤邏輯）

測試內容：
- 間歇訓練初始狀態
- 工作段/恢復段距離計算
- 目標配速獲取
- 完成狀態判斷
- 組合跑階段切換

### 測試覆蓋率目標

```
核心邏輯模組：      > 80%
UI 相關代碼：       > 50%
整體覆蓋率：        > 60%
```

### 查看測試覆蓋率

1. 在 Xcode 中運行測試（⌘U）
2. 打開 **Report Navigator** (⌘9)
3. 選擇最新的測試結果
4. 點擊 **Coverage** tab
5. 查看每個文件的覆蓋率

---

## 🎨 第2層：SwiftUI Previews（UI 預覽）

### 為什麼使用 SwiftUI Previews？

✅ **即時預覽** - 修改代碼立即看到效果
✅ **多設備預覽** - 同時預覽不同 Watch 尺寸
✅ **多狀態預覽** - 一次看到所有 UI 狀態
✅ **無需運行** - 不用編譯整個 app

### 如何使用 Previews

#### Step 1: 啟用 Canvas

1. 打開任意 SwiftUI View 文件（如 `ScheduleListView.swift`）
2. 點擊右上角的 **Canvas** 按鈕
3. 如果看不到預覽，點擊 **Resume**

#### Step 2: 創建測試數據的 Preview

在 `ScheduleListView.swift` 中添加：

```swift
#Preview("有課表") {
    NavigationStack {
        ScheduleListView()
            .environmentObject({
                let manager = WatchDataManager()

                // 創建測試課表
                let mockDay1 = WatchTrainingDay(
                    id: "1",
                    dayIndex: "2025-11-17",
                    dayTarget: "輕鬆跑 8 公里",
                    trainingType: "easy",
                    trainingDetails: WatchTrainingDetails(
                        description: "保持輕鬆配速",
                        distanceKm: 8.0,
                        totalDistanceKm: nil,
                        timeMinutes: 44,
                        pace: "5:30",
                        work: nil,
                        recovery: nil,
                        repeats: nil,
                        heartRateRange: WatchHeartRateRange(min: 120, max: 145),
                        segments: nil
                    )
                )

                let mockDay2 = WatchTrainingDay(
                    id: "2",
                    dayIndex: "2025-11-18",
                    dayTarget: "間歇跑 6×1000m",
                    trainingType: "interval",
                    trainingDetails: WatchTrainingDetails(
                        description: nil,
                        distanceKm: nil,
                        totalDistanceKm: 8.4,
                        timeMinutes: nil,
                        pace: nil,
                        work: WatchWorkoutSegment(
                            description: "工作段",
                            distanceKm: nil,
                            distanceM: 1000,
                            timeMinutes: nil,
                            pace: "4:00",
                            heartRateRange: nil
                        ),
                        recovery: WatchWorkoutSegment(
                            description: "恢復段",
                            distanceKm: nil,
                            distanceM: 400,
                            timeMinutes: nil,
                            pace: "6:00",
                            heartRateRange: nil
                        ),
                        repeats: 6,
                        heartRateRange: nil,
                        segments: nil
                    )
                )

                manager.weeklyPlan = WatchWeeklyPlan(
                    id: "test-plan",
                    weekOfPlan: 3,
                    totalWeeks: 12,
                    totalDistance: 50.0,
                    days: [mockDay1, mockDay2]
                )

                return manager
            }())
    }
}

#Preview("無課表") {
    NavigationStack {
        ScheduleListView()
            .environmentObject(WatchDataManager())
    }
}

#Preview("載入中") {
    NavigationStack {
        ScheduleListView()
            .environmentObject({
                let manager = WatchDataManager()
                manager.isLoading = true
                return manager
            }())
    }
}
```

#### Step 3: 預覽不同設備尺寸

```swift
#Preview("Apple Watch Series 9 (45mm)") {
    ScheduleListView()
        .previewDevice("Apple Watch Series 9 (45mm)")
}

#Preview("Apple Watch Series 8 (41mm)") {
    ScheduleListView()
        .previewDevice("Apple Watch Series 8 (41mm)")
}

#Preview("Apple Watch Ultra (49mm)") {
    ScheduleListView()
        .previewDevice("Apple Watch Ultra (49mm)")
}
```

### 為每個 View 創建 Previews

**WorkoutDetailView Previews**：

```swift
#Preview("簡單訓練") {
    NavigationStack {
        WorkoutDetailView(trainingDay: createMockEasyRun())
    }
}

#Preview("間歇訓練") {
    NavigationStack {
        WorkoutDetailView(trainingDay: createMockIntervalRun())
    }
}

#Preview("組合跑") {
    NavigationStack {
        WorkoutDetailView(trainingDay: createMockCombinationRun())
    }
}
```

**ActiveWorkoutView Previews**：

```swift
#Preview("心率模式") {
    ActiveWorkoutView(trainingDay: createMockEasyRun())
        .environmentObject(WatchDataManager())
}

#Preview("配速模式") {
    ActiveWorkoutView(trainingDay: createMockTempoRun())
        .environmentObject(WatchDataManager())
}

#Preview("間歇訓練") {
    ActiveWorkoutView(trainingDay: createMockIntervalRun())
        .environmentObject(WatchDataManager())
}
```

### Preview 測試清單

在 Preview 中檢查：
- [ ] 字體大小適合 Watch 螢幕
- [ ] 顏色對比度足夠（深色/淺色模式）
- [ ] 佈局不會溢出螢幕
- [ ] 圖標和圓點大小合適
- [ ] 按鈕觸控目標 >= 44pt
- [ ] 多行文字正確換行

---

## 🖥️ 第3層：模擬器測試（帶模擬數據）

### 創建測試數據注入系統

#### Step 1: 創建 MockDataProvider

創建 `PacerizWatch/Utils/MockDataProvider.swift`：

```swift
#if DEBUG
import Foundation

struct MockDataProvider {
    static func createMockWeeklyPlan() -> WatchWeeklyPlan {
        let days = [
            createMockDay(
                dayIndex: "2025-11-17",
                type: "easy",
                target: "輕鬆跑 8 公里",
                distance: 8.0,
                pace: "5:30",
                hrRange: (120, 145)
            ),
            createMockDay(
                dayIndex: "2025-11-18",
                type: "interval",
                target: "間歇跑 6×1000m",
                isInterval: true,
                workDistance: 1000,
                workPace: "4:00",
                recoveryDistance: 400,
                recoveryPace: "6:00",
                repeats: 6
            ),
            createMockDay(
                dayIndex: "2025-11-19",
                type: "combination",
                target: "組合跑 10 公里",
                isCombination: true
            ),
            createMockDay(
                dayIndex: "2025-11-20",
                type: "tempo",
                target: "節奏跑 8 公里",
                distance: 8.0,
                pace: "4:30"
            ),
            createMockDay(
                dayIndex: "2025-11-21",
                type: "lsd",
                target: "LSD 長距離 15 公里",
                distance: 15.0,
                pace: "5:45",
                hrRange: (125, 150)
            ),
            createMockDay(
                dayIndex: "2025-11-22",
                type: "recovery_run",
                target: "恢復跑 6 公里",
                distance: 6.0,
                pace: "6:00",
                hrRange: (115, 135)
            ),
            createMockDay(
                dayIndex: "2025-11-23",
                type: "rest",
                target: "休息日"
            )
        ]

        return WatchWeeklyPlan(
            id: "mock-plan-week-3",
            weekOfPlan: 3,
            totalWeeks: 12,
            totalDistance: 50.0,
            days: days
        )
    }

    static func createMockUserProfile() -> WatchUserProfile {
        let zones = [
            WatchHeartRateZone(zone: 1, name: "輕鬆", minHR: 135, maxHR: 155, description: "Z1 輕鬆區間"),
            WatchHeartRateZone(zone: 2, name: "馬拉松", minHR: 155, maxHR: 168, description: "Z2 馬拉松區間"),
            WatchHeartRateZone(zone: 3, name: "閾值", minHR: 168, maxHR: 174, description: "Z3 閾值區間"),
            WatchHeartRateZone(zone: 4, name: "有氧", minHR: 174, maxHR: 183, description: "Z4 有氧區間"),
            WatchHeartRateZone(zone: 5, name: "無氧", minHR: 183, maxHR: 190, description: "Z5 無氧區間")
        ]

        return WatchUserProfile(
            maxHR: 190,
            restingHR: 55,
            vdot: 48.5,
            heartRateZones: zones
        )
    }

    // ... 其他輔助方法 ...
}
#endif
```

#### Step 2: 在 WatchDataManager 中使用 Mock 數據

```swift
class WatchDataManager: NSObject, ObservableObject {
    // ...

    private override init() {
        super.init()

        #if DEBUG
        // 模擬器模式：自動載入測試數據
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || ProcessInfo.processInfo.environment["USE_MOCK_DATA"] == "1" {
            loadMockData()
        } else {
            loadFromCache()
        }
        #else
        loadFromCache()
        #endif

        // ... WatchConnectivity 設置 ...
    }

    #if DEBUG
    private func loadMockData() {
        self.weeklyPlan = MockDataProvider.createMockWeeklyPlan()
        self.userProfile = MockDataProvider.createMockUserProfile()
        self.lastSyncTime = Date()
        print("✅ MockData: 測試數據已載入")
    }
    #endif
}
```

#### Step 3: 在 Xcode Scheme 中啟用 Mock 數據

1. 選擇 **Product** → **Scheme** → **Edit Scheme...**
2. 選擇 **Run** → **Arguments**
3. 在 **Environment Variables** 中添加：
   - Name: `USE_MOCK_DATA`
   - Value: `1`
4. 點擊 **Close**

現在運行模擬器時會自動載入測試數據！

### 模擬器測試流程

#### 1. 啟動模擬器
```bash
# Xcode 中選擇 PacerizWatch scheme
# 選擇 Apple Watch Series 9 (45mm)
# 點擊 Run (⌘R)
```

#### 2. 測試課表列表
- [ ] 顯示 7 天課表
- [ ] 今天（11/17）高亮顯示
- [ ] 顏色圓點正確（綠色=輕鬆，橙色=間歇）
- [ ] 週數顯示「第 3/12 週」
- [ ] 下拉刷新動畫流暢

#### 3. 測試課表詳情
- [ ] 點擊輕鬆跑 → 顯示心率區間
- [ ] 點擊間歇跑 → 顯示工作段/恢復段
- [ ] 點擊組合跑 → 顯示所有階段（可滾動）
- [ ] 「開始訓練」按鈕可點擊

#### 4. 測試訓練頁面（模擬數據）

**模擬心率和配速**：

在 `WorkoutManager.swift` 中添加測試模式：

```swift
#if DEBUG
func startMockWorkout() {
    isActive = true

    // 模擬數據更新計時器
    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
        guard let self = self, self.isActive else {
            timer.invalidate()
            return
        }

        // 模擬心率（130-170 之間隨機）
        self.currentHR = Int.random(in: 130...170)

        // 模擬距離（每秒增加 3m，約 5:30/km）
        self.distance += 3.0

        // 模擬時間
        self.duration += 1.0

        // 模擬配速（5:00-5:30 之間隨機）
        self.currentPace = TimeInterval.random(in: 300...330)
        self.currentSpeed = 1000.0 / self.currentPace

        // 模擬卡路里
        self.activeCalories += 0.15

        // 更新分段追蹤器
        self.segmentTracker?.updateProgress(
            currentDistance: self.distance,
            currentSpeed: self.currentSpeed
        )
    }
}
#endif
```

在 `ActiveWorkoutView.swift` 中使用：

```swift
.task {
    #if DEBUG
    if ProcessInfo.processInfo.environment["USE_MOCK_DATA"] == "1" {
        workoutManager.startMockWorkout()
    } else {
        await workoutManager.startWorkout()
    }
    #else
    await workoutManager.startWorkout()
    #endif
}
```

現在可以在模擬器中測試完整的訓練流程！

---

## 📊 測試覆蓋矩陣

| 功能 | 單元測試 | Preview | 模擬器 | 真機 |
|------|---------|---------|--------|------|
| 配速計算 | ✅ | - | ✅ | ✅ |
| 心率區間判斷 | ✅ | - | ✅ | ✅ |
| 訓練類型判斷 | ✅ | - | ✅ | ✅ |
| 分段追蹤邏輯 | ✅ | - | ✅ | ✅ |
| UI 佈局 | - | ✅ | ✅ | ✅ |
| 頁面導航 | - | ✅ | ✅ | ✅ |
| 數據同步 | ❌ | - | ⚠️ | ✅ |
| HealthKit | ❌ | - | ❌ | ✅ |
| GPS 追蹤 | ❌ | - | ❌ | ✅ |
| 提示音/震動 | ❌ | - | ❌ | ✅ |

---

## ⚡ 快速測試流程（推薦）

### 每次修改代碼後（5 分鐘）

```bash
1. 運行單元測試 (⌘U)                 ⏱️ 30秒
2. 檢查 SwiftUI Preview             ⏱️ 1分鐘
3. 模擬器快速測試                    ⏱️ 3分鐘
```

### 完成新功能後（15 分鐘）

```bash
1. 運行所有單元測試                  ⏱️ 2分鐘
2. 檢查所有 Previews                ⏱️ 3分鐘
3. 模擬器完整測試                    ⏱️ 10分鐘
```

### 準備發布前（60 分鐘）

```bash
1. 運行所有測試 + 檢查覆蓋率        ⏱️ 5分鐘
2. 真機完整測試（見 TESTING_GUIDE） ⏱️ 55分鐘
```

---

## 🎯 測試最佳實踐

### ✅ DO

- 先寫測試，再寫代碼（TDD）
- 每個邏輯函數都有對應的單元測試
- 為每個 SwiftUI View 創建 Preview
- 使用有意義的測試名稱（test_Function_Scenario_ExpectedResult）
- 測試邊界情況和異常情況
- 保持測試獨立（不依賴其他測試）

### ❌ DON'T

- 不要跳過單元測試，直接真機測試
- 不要測試 UI 細節（如具體的顏色值）
- 不要在測試中使用真實的 API 調用
- 不要忽略測試失敗（必須修復或更新測試）
- 不要寫過於複雜的測試（測試本身也會有 bug）

---

## 🐛 常見問題

### Q: 單元測試找不到模組？

```
error: No such module 'PacerizWatch'
```

**解決方案**：
1. 確保測試 target 已正確設置
2. 在測試文件中使用 `@testable import PacerizWatch`
3. Clean Build Folder (⇧⌘K) 後重新編譯

---

### Q: SwiftUI Preview 無法載入？

```
Cannot preview in this file
```

**解決方案**：
1. 確保 View 是 `struct` 且符合 `View` protocol
2. 確保所有依賴都已注入（如 `.environmentObject()`）
3. 嘗試點擊 **Resume** 按鈕
4. 重啟 Xcode（最後手段）

---

### Q: 模擬器測試時 App 閃退？

**解決方案**：
1. 檢查 Console 錯誤信息
2. 確保所有強制解包（`!`）都有值
3. 確保環境變數正確設置
4. 使用 `print()` 調試數據流

---

## ✅ 測試完成清單

在提交代碼或真機測試前：

### 單元測試
- [ ] 所有測試通過（綠色）
- [ ] 核心邏輯覆蓋率 > 80%
- [ ] 無警告或棄用提示

### UI Previews
- [ ] 所有 View 都有 Preview
- [ ] Preview 在不同設備尺寸下正常
- [ ] 深色/淺色模式都測試過

### 模擬器測試
- [ ] 課表列表顯示正確
- [ ] 課表詳情完整
- [ ] 訓練頁面 UI 正確
- [ ] 模擬數據流暢更新
- [ ] 無明顯 UI bug

---

**測試金字塔原則**：
```
        真機測試 (5%)
      ↗             ↖
   模擬器測試 (15%)
  ↗                 ↖
單元測試 (80%)
```

大部分測試應該是單元測試（快速、可靠），只有硬體相關功能才需要真機測試。

需要我幫你創建更多特定功能的單元測試嗎？