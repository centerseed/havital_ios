# Spec: fix-v2-weekly-plan

## Goal
修復 V2 週課表產生流程的兩個 bug：
1. 星期一打開 app 還是顯示上週課表，要刷掉重開才正常
2. 產生完週回顧後無法馬上產生新課表，一直循環回「產生週回顧」

## Metadata
- affected: app
- db_migration: false
- deploy_required: false

## Acceptance Criteria

### @ac1: App 從背景回前景時自動刷新 currentWeek
**GIVEN** App 在背景中，且後端的 currentWeek 已更新（例如從第 2 週進入第 3 週）
**WHEN** 用戶將 App 從背景切回前景
**THEN** `TrainingPlanV2View` 自動重新呼叫 `viewModel.initialize()`，取得最新的 `currentWeek` 並顯示正確的週課表

**根因**: `TrainingPlanV2View` 只用 `.task` 做初始化，沒有監聽 `willEnterForegroundNotification`。V1 的 `TrainingPlanView.swift:229` 有此監聽但 V2 漏了。

### @ac2: 週回顧產生後，Loading Sheet 正確轉場到 Summary Sheet
**GIVEN** 用戶處於 `needsWeeklySummary` 狀態，按下「產生週回顧」
**WHEN** 週回顧 API 呼叫成功完成
**THEN** Loading sheet 先關閉，等待 dismiss 動畫完成後，Summary sheet 正確彈出，不會被靜默丟棄

**根因**: `createWeeklySummaryAndShow()` 在 line 892 設 `isLoadingAnimation = false`（loading sheet 開始關閉），然後在 line 900 設 `showWeeklySummary = true`（summary sheet 要開啟）。SwiftUI 同時間只能處理一個 sheet 轉場，loading sheet 的 dismiss 動畫（~0.3-0.5s）還沒完成就嘗試 present summary sheet，summary sheet 被靜默丟棄。用戶回到主畫面，`planStatus` 仍是 `.needsWeeklySummary` → 無限循環。

## Implementation Plan

### Bug 1 Fix — File: `Havital/Features/TrainingPlanV2/Presentation/Views/TrainingPlanV2View.swift`

在 `.task { await viewModel.initialize() }` 之後加入：
```swift
.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
    Task {
        await viewModel.initialize()
    }
}
```

參考 V1 實作：`Havital/Views/Training/TrainingPlanView.swift:229`

### Bug 2 Fix — File: `Havital/Features/TrainingPlanV2/Presentation/ViewModels/TrainingPlanV2ViewModel.swift`

修改 `createWeeklySummaryAndShow()` 方法（~line 881-921）：
1. API 成功後，先執行 `refreshPlanStatusResponse()`（趁 loading sheet 還在時做）
2. 設 `isLoadingAnimation = false`（開始關閉 loading sheet）
3. 加入 `try? await Task.sleep(nanoseconds: 600_000_000)` 等待 0.6s dismiss 動畫完成
4. 再設 `showWeeklySummary = true`

修改後的 do block：
```swift
do {
    let summary = try await repository.generateWeeklySummary(weekOfPlan: week, forceUpdate: false)

    weeklySummary = .loaded(summary)

    // 趁 loading sheet 還在時先更新 planStatusResponse
    await refreshPlanStatusResponse()

    // 關閉 loading sheet
    isLoadingAnimation = false
    isLoadingWeeklySummary = false
    isGeneratingSummary = false

    // 等待 loading sheet dismiss 動畫完成
    try? await Task.sleep(nanoseconds: 600_000_000)

    // 再開啟 summary sheet
    showWeeklySummary = true

    Logger.info("[TrainingPlanV2VM] ✅ 週摘要產生成功，顯示 sheet")
}
```

## Files Expected to Change

| File | Change |
|------|--------|
| `Havital/Features/TrainingPlanV2/Presentation/Views/TrainingPlanV2View.swift` | 加入 `.onReceive(willEnterForegroundNotification)` |
| `Havital/Features/TrainingPlanV2/Presentation/ViewModels/TrainingPlanV2ViewModel.swift` | 調整 `createWeeklySummaryAndShow()` sheet 切換順序 + 延遲 |

## Files That Must NOT Change
- Domain layer entities
- Data layer DTOs/Mappers
- Repository protocols/implementations
- Other ViewModels

## Out of Scope
- V1 TrainingPlanView 的修改（V1 已棄用）
- currentWeek 計算邏輯的修改（後端負責）
- Loading 動畫本身的修改

## E2E Verification

### 前置條件
使用 `/reset-v2-weekly-plan` skill 重置測試用戶 `E4IU0VafRAdlNXoVHFzN0LZmOZ82` 的 Firestore 資料

### Bug 2 驗證流程
1. Build & install app 到 simulator
2. SSO 登入測試帳號
3. 進入訓練計畫頁面，應顯示需要產生週課表的狀態
4. 按「產生週課表」按鈕
5. 確認 loading 動畫出現 → loading 結束後 summary sheet 正確彈出
6. 在 summary sheet 中操作產生下週課表

### Bug 1 驗證
- 功能性驗證需要跨天測試，E2E 中主要確認 `.onReceive` 有被正確加入（code review 驗證）
