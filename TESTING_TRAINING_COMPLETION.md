# 訓練完成 UI 流程測試指南

## 🎯 測試目標

驗證當訓練計畫完成時（currentWeek > totalWeeks），系統是否正確顯示完成 UI 和「設定新目標」按鈕。

## 🐛 修復的問題

**問題描述**：用戶 `iaMuFQEjoYQZhpxf4qyKAJanLjG2` 完成訓練後（第 4 週 / 總共 3 週），沒有看到「設定新目標」提示。

**根本原因**：
1. `refreshWeeklyPlan()` 沒有檢查 `trainingCompleted` 狀態，導致 `planStatus` 被覆蓋
2. `TrainingProgressView` 沒有處理訓練完成的情況

**修復內容**：
1. `TrainingPlanViewModel.swift` Line 806-812：在 `refreshWeeklyPlan()` 中優先檢查訓練完成狀態
2. `TrainingProgressView.swift`：
   - 使用 `trainingOverview.totalWeeks` 作為主要數據來源
   - 訓練完成時顯示「設定新目標」按鈕
   - 保留原始進度顯示內容

---

## 📋 測試方法

### 方法 1：使用 SwiftUI Preview（推薦 - 最快速）

#### 步驟 1：打開 Preview

在 Xcode 中打開：
```
Havital/PreviewHelpers/TrainingCompletionPreviewView.swift
```

#### 步驟 2：啟動 Canvas

- 按下 `⌥⌘↩` (Option + Command + Enter) 或點擊右上角的 "Canvas" 按鈕
- 等待 Preview 編譯完成

#### 步驟 3：測試各種場景

使用頂部的 Segmented Control 切換三種測試場景：

**場景 1：訓練完成（第 4 週 / 總共 3 週）**
- [ ] 主畫面 Tab：應顯示 "🎉 恭喜！訓練週期已完成"
- [ ] 主畫面 Tab：應顯示綠色「設定新目標」按鈕
- [ ] 進度畫面 Tab：應顯示 "第 4 週 / 總共 3 週"
- [ ] 進度畫面 Tab：進度條應為 100%（藍綠漸層）
- [ ] 進度畫面 Tab：應顯示綠色「設定新目標」按鈕

**場景 2：正常進行中（第 2 週 / 總共 3 週）**
- [ ] 主畫面 Tab：應顯示本週訓練課表
- [ ] 進度畫面 Tab：進度條應為 ~67%
- [ ] 兩個畫面都**不應該**顯示「設定新目標」按鈕

**場景 3：最後一週（第 3 週 / 總共 3 週）**
- [ ] 主畫面 Tab：應顯示本週訓練課表
- [ ] 進度畫面 Tab：進度條應為 100%
- [ ] 兩個畫面都**不應該**顯示「設定新目標」按鈕（因為尚未完成）

#### 步驟 4：驗證按鈕點擊

點擊「設定新目標」按鈕時，在 Xcode Console 中應看到：
```
✅ 測試：觸發 startReonboarding()
```
或
```
✅ 測試：從進度畫面觸發 startReonboarding()
```

---

### 方法 2：模擬器手動測試

#### 準備工作

1. **修改 Mock 數據**（臨時用於測試）

在 `TrainingPlanViewModel.swift` 的 `loadPlanStatus()` 函數中，臨時添加測試數據：

```swift
func loadPlanStatus(skipCache: Bool = false) async {
    // ⚠️ 測試用臨時代碼 - 測試完成後刪除
    #if DEBUG
    let testResponse = PlanStatusResponse(
        currentWeek: 4,  // 超過 totalWeeks
        totalWeeks: 3,
        nextAction: .trainingCompleted,
        canGenerateNextWeek: false,
        currentWeekPlanId: nil,
        previousWeekSummaryId: nil,
        nextWeekInfo: nil,
        metadata: PlanStatusMetadata(
            trainingStartDate: "2026-01-01",
            currentWeekStartDate: "2026-01-20",
            currentWeekEndDate: "2026-01-26",
            userTimezone: "Asia/Taipei",
            serverTime: "2026-01-22T10:00:00Z"
        )
    )
    planStatusResponse = testResponse
    planStatus = .completed
    Logger.debug("[TrainingPlanVM] 🧪 測試模式：使用訓練完成狀態")
    return
    #endif

    // ... 原始代碼繼續
}
```

2. **構建並運行**

```bash
cd "/Users/wubaizong/havital/apps/ios/Havital"
xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 16'
```

或直接在 Xcode 中按 `⌘R`

#### 測試步驟

**測試 1：主畫面顯示**
1. 登入應用
2. 進入「訓練計畫」頁面
3. 驗證顯示 `FinalWeekPromptView`：
   - [ ] 看到完成訊息
   - [ ] 看到「設定新目標」按鈕
4. 點擊「設定新目標」按鈕
5. 驗證是否觸發 re-onboarding 流程

**測試 2：進度畫面顯示**
1. 從主畫面點擊進入「訓練進度」頁面
2. 驗證顯示內容：
   - [ ] "第 4 週 / 總共 3 週"
   - [ ] 進度條為 100%（限制在 max 1.0）
   - [ ] 顯示當前階段資訊
   - [ ] 顯示「設定新目標」按鈕
3. 點擊「設定新目標」按鈕
4. 驗證是否：
   - [ ] 關閉 `TrainingProgressView`
   - [ ] 觸發 re-onboarding 流程

**測試 3：下拉刷新保持完成狀態**
1. 在主畫面時，執行下拉刷新（Pull to Refresh）
2. 驗證：
   - [ ] 刷新後仍然顯示完成狀態
   - [ ] 不會變回顯示課表
   - [ ] `planStatus` 保持為 `.completed`

---

### 方法 3：使用真實生產數據

**⚠️ 僅用於驗證真實用戶問題**

如果需要重現用戶 `iaMuFQEjoYQZhpxf4qyKAJanLjG2` 的問題：

1. **登入測試帳號**
   - 使用該用戶的憑證登入（需要用戶授權）

2. **檢查後端返回**
   - 查看日誌中的 API 回應
   - 確認後端返回 `next_action: "training_completed"`

3. **驗證前端顯示**
   - 主畫面是否顯示完成 UI
   - 進度畫面是否顯示完成按鈕

---

## 🔍 關鍵驗證點

### 主畫面 (TrainingPlanView)

**當 `planStatus == .completed` 時：**
- ✅ 顯示 `FinalWeekPromptView`
- ✅ 顯示完成訊息
- ✅ 顯示「設定新目標」按鈕
- ✅ 點擊按鈕觸發 `authViewModel.startReonboarding()`

**當下拉刷新時：**
- ✅ `refreshWeeklyPlan()` 檢測到 `nextAction == .trainingCompleted`
- ✅ 早期返回，保持 `planStatus = .completed`
- ✅ 不會錯誤地設置為 `.ready(plan)` 或 `.noPlan`

### 進度畫面 (TrainingProgressView)

**當 `isTrainingCompleted` 為 true 時：**
- ✅ 顯示 "第 X 週 / 總共 Y 週"（X > Y）
- ✅ 進度條為 100%（使用 `min(progress, 1.0)`）
- ✅ 顯示當前階段資訊（如果存在）
- ✅ 在進度卡片底部顯示「設定新目標」按鈕
- ✅ 點擊按鈕觸發 `dismiss()` → `authViewModel.startReonboarding()`

**當 `weeklyPlan` 為 nil 時：**
- ✅ 使用 `trainingOverview.totalWeeks` 作為備用數據源
- ✅ 不會因為 `weeklyPlan == nil` 而崩潰或不顯示

### 日誌驗證

搜尋以下日誌關鍵字：

**訓練完成檢測**：
```
[TrainingPlanVM] Training completed (nextAction: training_completed)
[TrainingPlanVM] ✅ Training completed detected during refresh
```

**狀態更新**：
```
[TrainingPlanVM] Plan status updated: completed
```

**API 調用追蹤**：
```
📱 [API Call] TrainingPlanView: refreshWeeklyPlan → GET /plan/race_run/status
✅ [API End] TrainingPlanView: refreshWeeklyPlan → GET /plan/race_run/status | 200 | 0.34s
```

---

## 🧪 自動化測試（可選）

### 單元測試

如果需要建立單元測試：

```swift
// HavitalTests/Features/TrainingPlan/TrainingCompletionTests.swift
import XCTest
@testable import Havital

final class TrainingCompletionTests: XCTestCase {

    func testRefreshWeeklyPlan_WhenTrainingCompleted_MaintainsCompletedStatus() async {
        // Given
        let mockRepository = MockTrainingPlanRepository()
        mockRepository.mockPlanStatusResponse = PlanStatusResponse(
            currentWeek: 4,
            totalWeeks: 3,
            nextAction: .trainingCompleted,
            /* ... */
        )
        let viewModel = TrainingPlanViewModel(repository: mockRepository, /* ... */)

        // When
        await viewModel.loadPlanStatus()
        await viewModel.refreshWeeklyPlan()

        // Then
        XCTAssertEqual(viewModel.planStatus, .completed)
    }

    func testTrainingProgressView_WhenCompleted_ShowsSetNewGoalButton() {
        // Given
        let viewModel = MockTrainingPlanViewModel()
        viewModel.setupCompletedState()

        // When
        let view = TrainingProgressView(viewModel: viewModel)

        // Then
        // 驗證 view 包含「設定新目標」按鈕
        // (需要 ViewInspector 或 snapshot testing)
    }
}
```

---

## 📊 測試報告範本

複製以下範本到測試結果報告：

```markdown
## 測試執行報告

**測試日期**：YYYY-MM-DD
**測試者**：[姓名]
**測試方法**：[Preview / Simulator / Production]
**iOS 版本**：[版本]
**裝置**：[裝置型號]

### 測試結果

#### ✅ 主畫面測試
- [x] 訓練完成時顯示完成訊息
- [x] 顯示「設定新目標」按鈕
- [x] 點擊按鈕觸發 re-onboarding
- [x] 下拉刷新保持完成狀態

#### ✅ 進度畫面測試
- [x] 顯示正確週數（4 / 3）
- [x] 進度條限制在 100%
- [x] 顯示「設定新目標」按鈕
- [x] 點擊按鈕觸發 re-onboarding
- [x] weeklyPlan 為 nil 時不崩潰

#### ✅ 日誌驗證
- [x] 檢測到訓練完成日誌
- [x] 刷新時保持完成狀態日誌
- [x] API 調用追蹤正確

### 發現的問題

[列出任何發現的問題]

### 建議

[列出任何改進建議]
```

---

## 🚀 快速測試指令

```bash
# 構建並運行
cd "/Users/wubaizong/havital/apps/ios/Havital"
xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 16'

# 搜尋相關代碼
grep -r "trainingCompleted" Havital/ --include="*.swift"
grep -r "isTrainingCompleted" Havital/ --include="*.swift"
grep -r "FinalWeekPromptView" Havital/ --include="*.swift"

# 檢查日誌
tail -f ~/Library/Logs/Havital/app.log | grep "Training"
```

---

## ✅ 完成檢查清單

- [ ] Preview 測試三種場景全部通過
- [ ] 模擬器測試主畫面顯示正確
- [ ] 模擬器測試進度畫面顯示正確
- [ ] 下拉刷新保持完成狀態
- [ ] 點擊按鈕觸發 re-onboarding
- [ ] 日誌記錄正確
- [ ] 移除所有臨時測試代碼
- [ ] 提交代碼前進行最終驗證

---

**注意**：測試完成後，記得移除所有添加的臨時測試代碼（如在 `loadPlanStatus` 中的 `#if DEBUG` 區塊）。
