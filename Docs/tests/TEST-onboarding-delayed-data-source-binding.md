---
type: TEST
id: TEST-onboarding-delayed-data-source-binding
status: Draft
l2_entity: 訓練計畫系統
source_spec: SPEC-onboarding-delayed-data-source-binding
created: 2026-04-22
updated: 2026-04-22
changelog:
  - 2026-04-22: 初版測試設計，對齊 onboarding 延後綁定資料來源 spec
---

# Test Design: Onboarding 延後綁定資料來源

## 目標

驗證 iOS onboarding 支援 `稍後再設定`，並在 `data_source = unbound` 時透過主 app 既有 alert 做每 3 天一次的非阻斷提醒。

## 範圍與非範圍

範圍：

- `DataSourceSelectionView` 的 skip path
- `unbound` 寫入與 onboarding 繼續行為
- `ContentView` 未綁定提醒
- `UserProfileView` 補綁入口
- reminder cadence（3 天 + session 抑制）

非範圍：

- Garmin / Strava OAuth SDK 細節
- 歷史資料同步完成後的課表重算
- Android / Flutter 行為

## 測試層級策略

| 層級 | 工具 | 目的 | Gate |
|---|---|---|---|
| Unit | XCTest | 驗證 `DataSourceBindingReminderManager` 的 3 天節流與 session 抑制 | P0 必過 |
| Integration | XCTest + Mock ViewModel / Notification | 驗證 `.dataSourceNotBound` 到 `AppViewModel.showDataSourceNotBoundAlert` 的轉換規則 | P0 必過 |
| UI | XCUITest | 驗證 onboarding skip、alert 顯示、Go to Settings 開 profile | P0 必過 |
| Manual | Simulator / 真機 | 驗證 Garmin/Strava 既有連線流程未被 skip path 破壞 | P1 應跑 |

## 需求追蹤矩陣

| Spec 需求 | 對應測試案例 |
|---|---|
| P0-1 onboarding 可在未綁定狀態完成 | P0-S01, P0-S02 |
| P0-2 `稍後再設定` = `unbound` | P0-S03 |
| P0-3 skip path 不直接進 OAuth | P0-S04 |
| P0-4 主 app 非阻斷提醒 | P0-S05, P0-S06 |
| P0-5 補綁後不再被未綁定提醒打擾 | P0-S07 |
| P1-1 每 3 天一次 | P0-S08, P0-S09 |
| P1-2 alert / profile 語意一致 | P0-S10 |

## P0 場景（必須全部通過）

### S1: 點擊 `稍後再設定` 可繼續 onboarding
層級：UI
Given: 新用戶進入 `DataSourceSelectionView`
When: 點擊 `稍後再設定`
Then: 流程前進到下一步，不顯示 Garmin / Strava / Apple Health 授權流程

### S2: `unbound` 路徑仍可完成課表生成
層級：UI + Integration
Given: 使用者在資料來源步驟選 `稍後再設定`
When: 完成後續 onboarding 必填步驟
Then: onboarding 可完成，且不因未綁定被送回 onboarding

### S3: skip path 會保存 `data_source = unbound`
層級：Integration
Given: 使用者在 onboarding 點擊 `稍後再設定`
When: `updateAndSyncDataSource(.unbound)` 完成
Then: 本地與後端資料來源值都為 `unbound`

### S4: skip path 不啟動任何 OAuth
層級：UI + Unit
Given: 使用者在資料來源步驟點擊 `稍後再設定`
When: 系統處理該 action
Then: `GarminManager.startConnection()`、`StravaManager.startConnection()`、`HealthKitManager.requestAuthorization()` 都不被呼叫

### S5: onboarding 完成後，未綁定提醒走 `ContentView` 既有 alert
層級：Integration + UI
Given: onboarding 已完成且後端 `data_source = unbound`
When: `AuthenticationService` 發送 `.dataSourceNotBound`
Then: `AppViewModel.showDataSourceNotBoundAlert == true`，且 UI 顯示既有 alert 文案與按鈕

### S6: 點擊 `Go to Settings` 會打開 `UserProfileView`
層級：UI
Given: `ContentView` 正顯示未綁定 alert
When: 點擊 `Go to Settings`
Then: alert 關閉並打開 `UserProfileView` sheet

### S7: 一旦資料來源改為 Apple Health / Garmin / Strava，不再顯示未綁定提醒
層級：Integration
Given: 使用者已完成補綁，`data_source != unbound`
When: app 再次收到登入後資料同步或前景事件
Then: 不顯示 `showDataSourceNotBoundAlert`

### S8: 未綁定提醒每 3 天最多一次
層級：Unit
Given: 上次顯示時間為 T0
When: 在 T0 + 1 天、T0 + 2 天再次檢查
Then: manager 回傳不顯示

### S9: 同 session 不重複彈未綁定提醒
層級：Unit + Integration
Given: 本 session 已顯示過一次未綁定提醒
When: 再次收到 `.dataSourceNotBound`
Then: 不再次顯示 alert

### S10: alert 與 profile 使用一致的未綁定語意
層級：UI
Given: 使用者資料來源為 `unbound`
When: 分別查看 `ContentView` alert 與 `UserProfileView` data source section
Then: 兩邊都表達為「尚未連接 / 可前往設定補綁」，沒有假裝是 Apple Health 預設

## P1 場景（應通過）

### S1: Garmin / Strava 正常連線流程不回歸
層級：Manual
Given: 使用者在 onboarding 選 Garmin 或 Strava
When: 照原流程操作
Then: 既有 OAuth / already-bound 提示仍正常工作

### S2: `Later` 關閉提醒但不影響課表使用
層級：UI
Given: 使用者看到未綁定 alert
When: 點擊 `Later`
Then: alert 關閉，主 app 保持可用
