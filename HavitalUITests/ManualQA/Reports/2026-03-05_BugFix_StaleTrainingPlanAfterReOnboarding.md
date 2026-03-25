# Bug Fix Verification: Re-Onboarding Stale Training Plan

**日期**: 2026-03-05
**測試人員**: Claude (UI QA Agent)
**目的**: 驗證 Fix 1/2/3 是否解決「重新 onboarding 後 UI 仍顯示舊課表」的問題

---

## 修改摘要

| Fix | 位置 | 說明 |
|-----|------|------|
| Fix 1 | `backgroundRefreshWeeklyPlan` | 在更新 UI 前確認 `planOverview?.id == overviewId`，discarding stale result |
| Fix 2 | `backgroundRefreshOverview` | API call 前 capture `initialOverviewId`，re-onboarding 後舊 refresh 不蓋新計畫 |
| Fix 3 | `CompleteOnboardingUseCase.execute()` | 移除重複的 `publishCompletionEvent()` 呼叫及整個 private method |

---

## 測試環境

- **裝置**: iPhone 16e Simulator (iOS 26.2)
- **App**: paceriz_dev (build from dev_train_V2 branch)
- **帳號**: Demo User (Apple Review)

---

## 測試流程

### 初始狀態（re-onboarding 前）

- 訓練進度：**第 2/5 週**
- 本週目標跑量：**0/28 公里**
- 本週課表：星期一 休息、星期二 巡航間歇、星期三 休息、星期四 短間歇

### Re-Onboarding 操作步驟

1. ⋯ 選單 → 個人資料 → 滑到底部 → 重新設定目標 → 確認
2. PB: 5K / 25:00（配速 5:00/km）→ 下一步
3. 週跑量: 10km（預設）→ 下一步
4. 目標類型: 賽事訓練 → 下一步
5. 設定訓練目標: 全程馬拉松 4:00:00（預設）→ 下一步
6. 起始階段: 增強期（推薦）→ 繼續
7. 訓練方法: Paceriz 平衡訓練法（預設）→ 下一步
8. 訓練偏好: 二/四/六，長跑日週六 → 產生訓練計劃總覽
9. 訓練總覽確認 → 確認並生成第一週計劃

---

## 驗證結果

### 關鍵測試：Re-Onboarding 後 UI 立即顯示新計畫（不重啟 App）

| 指標 | Re-Onboarding 前 | Re-Onboarding 後（不重啟）| 結果 |
|------|-----------------|--------------------------|------|
| 訓練進度週數 | **第 2/5 週** | **第 1/5 週** | PASS |
| 本週目標跑量 | **0/28 公里** | **0/16 公里** | PASS |
| 是否需要重啟 App | — | **否** | PASS |

**截圖**: `Screenshots/2026-03-05/BugFix_ReOnboarding_NewPlanShown.png`

### 結論

**BUG 已修復**。Re-onboarding 完成後，Training Plan tab 立即顯示新計畫（第 1/5 週，週目標 16km），不需要重啟 App。

舊課表的 background refresh 結果被正確丟棄（因為 `planOverview?.id` 已換成新計畫的 ID）。

---

## Build 驗證

```
xcodebuild clean build -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17'
** BUILD SUCCEEDED **
```

只有既有的 deprecation warnings，無新錯誤。

---

## 整體評估

| # | 驗證項目 | 結果 |
|---|---------|------|
| 1 | Re-onboarding 後 UI 立即顯示新計畫 | PASS |
| 2 | 不需要重啟 App | PASS |
| 3 | Build 無新錯誤 | PASS |
| 4 | 舊 background refresh 結果被丟棄（guard overviewId）| PASS (by logic) |
| 5 | 重複 onboardingCompleted 事件已移除 | PASS (by code) |

**總體**: 5/5 PASS — Bug 修復驗證完成
