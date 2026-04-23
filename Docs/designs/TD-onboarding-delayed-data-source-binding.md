---
type: TD
id: TD-onboarding-delayed-data-source-binding
status: Draft
spec: SPEC-onboarding-delayed-data-source-binding.md
created: 2026-04-22
updated: 2026-04-22
---

# 技術設計：Onboarding 延後綁定資料來源

## 調查報告

### 已讀檔案與具體發現

- `Docs/specs/SPEC-onboarding-delayed-data-source-binding.md`：產品邊界已定案，主提醒 surface = `ContentView` alert；`unbound` 用戶每 3 天最多提醒一次。
- `Havital/Views/Onboarding/DataSourceSelectionView.swift`：目前只有 Apple Health / Garmin / Strava 三選一；Garmin / Strava 會在 onboarding 內直接啟動 OAuth；沒有 `稍後再設定`。
- `Havital/Features/UserProfile/Infrastructure/UserPreferencesService.swift`：`DataSourceType` 已有 `unbound`、`apple_health`、`garmin`、`strava` 四個正式值。
- `Havital/Services/Authentication/AuthenticationService.swift:913-959`：onboarding 完成後若後端 `data_source` 為 `nil` 或 `unbound`，會發送 `.dataSourceNotBound` 通知。
- `Havital/Core/Presentation/ViewModels/AppViewModel.swift:11-68`：目前收到 `.dataSourceNotBound` 後會直接把 `showDataSourceNotBoundAlert = true`，沒有頻率節流。
- `Havital/Views/ContentView.swift:207-216`：已有未綁定 alert，但 `Go to Settings` 仍是 TODO，現在只會關閉 alert。
- `Havital/Views/UserProfileView.swift:1299-1708`：profile data source section 已支援 `unbound` 顯示與 Apple Health / Garmin / Strava 切換，是現成的靜態補綁入口。
- `Havital/Features/Subscription/Domain/Managers/SubscriptionReminderManager.swift`：已有 reminder manager + `UserDefaults` 節流模式，可直接借鏡，不需要重新發明機制。

## 設計目標

1. onboarding 資料來源步驟加入 `稍後再設定`，讓使用者可在 `unbound` 狀態下繼續完成課表。
2. `unbound` 提醒沿用既有 `ContentView` alert 路徑，不新增新 modal 類型。
3. 未綁定提醒節流為每 3 天最多一次，且同一個 session 不重複彈。
4. `Go to Settings` 必須能真的打開 `UserProfileView`，不是只有關閉 alert。

## 非目標

- 不重構 Garmin / Strava OAuth SDK / callback 實作。
- 不重做 `UserProfileView` 的 data source section UI。
- 不在本次把「後綁完成後是否立即重算課表」做成實作。

## 架構決策

### 決策 1：Onboarding 的 `稍後再設定` 用次要 CTA，不做第四張 card

`DataSourceSelectionView` 目前已包在 `OnboardingPageTemplate`，且該 template 原生支援 `skipTitle / skipAction`。最小改動是：

- 主 CTA 仍只處理 Apple Health / Garmin / Strava 三種選擇。
- 新增次要文字按鈕 `稍後再設定`。
- 點擊後直接執行 `updateAndSyncDataSource(.unbound)`，然後導到 `.heartRateZone`。

這樣不需要把 `unbound` 做成與 Apple Health / Garmin / Strava 並列的來源卡，也符合產品語意：這不是正式資料來源，而是延後決策。

### 決策 2：提醒節流做成獨立 manager，但不重建新的 alert flow

`ContentView` 已有 alert，`AppViewModel` 已有 `showDataSourceNotBoundAlert`。本次不新增新的 published reminder enum，也不複製 `SubscriptionReminderManager` 的 UI 介面；只借它的節流模式。

新增：

`Havital/Features/UserProfile/Domain/Managers/DataSourceBindingReminderManager.swift`

```swift
@MainActor
final class DataSourceBindingReminderManager {
    static let shared = DataSourceBindingReminderManager()

    private var hasShownThisSession = false

    private enum Keys {
        static let lastShownAt = "data_source_unbound_last_shown_at"
    }

    func shouldShowReminder(now: Date = Date()) -> Bool
    func dismissReminder()
    func resetSession()
}
```

規則：

- 第一次命中 `.dataSourceNotBound`：若距離上次顯示 >= 3 天，回傳 `true`，並立即寫入 `lastShownAt`。
- 同 session 再次命中：直接 `false`。
- 使用者關閉 alert 或點 `Go to Settings`：呼叫 `dismissReminder()`。
- 新 session 開始時（app cold start）可重置 `hasShownThisSession`，但 3 天冷卻仍由 `UserDefaults` 主導。

### 決策 3：`AppViewModel` 負責把 raw notification 轉成「是否真的顯示 alert」

目前 raw path 是：

`AuthenticationService` -> `.dataSourceNotBound` notification -> `AppViewModel.showDataSourceNotBoundAlert = true`

修改後：

```swift
NotificationCenter.default.addObserver(
    forName: .dataSourceNotBound,
    object: nil,
    queue: .main
) { [weak self] _ in
    guard DataSourceBindingReminderManager.shared.shouldShowReminder() else { return }
    self?.showDataSourceNotBoundAlert = true
}
```

這樣 `AuthenticationService` 不需要知道節流規則；提醒頻率只在 presentation boundary 控制。

### 決策 4：`Go to Settings` 直接開 `UserProfileView` sheet

`ContentView` 目前按下 `Go to Settings` 沒有真的導頁。這次直接在 `ContentView` 補一個本地 sheet state：

```swift
@State private var showUserProfileForDataSourceBinding = false
```

alert button 改成：

```swift
Button(L10n.ContentView.goToSettings.localized) {
    appViewModel.showDataSourceNotBoundAlert = false
    DataSourceBindingReminderManager.shared.dismissReminder()
    showUserProfileForDataSourceBinding = true
}
```

並新增：

```swift
.sheet(isPresented: $showUserProfileForDataSourceBinding) {
    NavigationStack {
        UserProfileView(isShowing: $showUserProfileForDataSourceBinding)
    }
}
```

這樣主提醒與靜態入口都收斂到既有 `UserProfileView`，不需要再發明新的 data source settings 頁。

## Implementation Slice

### Slice A：Onboarding skip path

檔案：

- `Havital/Views/Onboarding/DataSourceSelectionView.swift`

改動：

1. `OnboardingPageTemplate` 加上 `skipTitle: L10n.Common.later.localized` 或新的 onboarding localized key `稍後再設定`。
2. 新增 `handleSkipDataSourceBinding()`：
   - `isProcessing = true`
   - `try await viewModel.updateAndSyncDataSource(.unbound)`
   - `coordinator.navigate(to: .heartRateZone)`
3. skip path 不呼叫 `HealthKitManager.requestAuthorization()`、`GarminManager.startConnection()`、`StravaManager.startConnection()`。

### Slice B：Reminder throttling

檔案：

- `Havital/Features/UserProfile/Domain/Managers/DataSourceBindingReminderManager.swift`（new）
- `Havital/Core/Presentation/ViewModels/AppViewModel.swift`

改動：

1. 新增 manager，節流規則固定為 3 天。
2. `AppViewModel` observer 改成先問 manager 再決定是否顯示 alert。
3. `AppViewModel` 新增：

```swift
func dismissDataSourceNotBoundAlert() {
    showDataSourceNotBoundAlert = false
    DataSourceBindingReminderManager.shared.dismissReminder()
}
```

### Slice C：Settings routing

檔案：

- `Havital/Views/ContentView.swift`

改動：

1. 新增 `@State private var showUserProfileForDataSourceBinding = false`
2. 未綁定 alert 的兩顆按鈕都改成呼叫 `appViewModel.dismissDataSourceNotBoundAlert()`
3. `Go to Settings` 額外把 `showUserProfileForDataSourceBinding = true`
4. 新增 `UserProfileView` sheet

## Spec Compliance Matrix

| Spec AC | 實作位置 | 對應測試 | 狀態 |
|---|---|---|---|
| AC-ONB-BIND-01a | `DataSourceSelectionView.skipAction` | `test_ac_onb_bind_01a_unbound_path_does_not_block_onboarding` | STUB |
| AC-ONB-BIND-01b | `DataSourceSelectionView.handleSkipDataSourceBinding()` + `OnboardingCoordinator` | `test_ac_onb_bind_01b_skip_sets_unbound_and_continues` | STUB |
| AC-ONB-BIND-02a | `UserProfileFeatureViewModel.updateAndSyncDataSource(.unbound)` | `test_ac_onb_bind_02a_skip_persists_unbound` | STUB |
| AC-ONB-BIND-03b | `DataSourceSelectionView.skipAction` no OAuth path | `test_ac_onb_bind_03b_skip_does_not_start_oauth` | STUB |
| AC-ONB-BIND-04a | `ContentView` existing alert + `AppViewModel` observer | `test_ac_onb_bind_04a_unbound_alert_uses_contentview_path` | STUB |
| AC-ONB-BIND-04d | `ContentView` sheet -> `UserProfileView` | `test_ac_onb_bind_04d_go_to_settings_opens_profile_sheet` | STUB |
| AC-ONB-BIND-05b | no code change; guarded by current non-blocking alert path | `test_ac_onb_bind_05b_alert_does_not_block_plan_usage` | STUB |
| AC-ONB-BIND-06a | `DataSourceBindingReminderManager` 3-day cadence | `test_ac_onb_bind_06a_unbound_reminder_shows_once_per_3_days` | STUB |
| AC-ONB-BIND-06a-1 | `DataSourceBindingReminderManager.hasShownThisSession` | `test_ac_onb_bind_06a_1_same_session_no_repeat` | STUB |
| AC-ONB-BIND-06b | `AppViewModel` observer + current data source checks | `test_ac_onb_bind_06b_connected_source_suppresses_reminder` | STUB |
| AC-ONB-BIND-07a | `ContentView` alert copy + `UserProfileView` unbound banner | `test_ac_onb_bind_07a_alert_and_profile_share_unbound_language` | STUB |

## 任務拆分

| # | 任務 | 角色 | Done Criteria |
|---|---|---|---|
| S01 | 實作 onboarding `稍後再設定` | Developer | `DataSourceSelectionView` 出現 skip path；點擊後保存 `unbound` 並前進；不啟動任何 OAuth |
| S02 | 實作未綁定提醒節流 | Developer | `DataSourceBindingReminderManager` 可控制每 3 天最多一次；同 session 不重複 |
| S03 | 補 `Go to Settings` routing | Developer | `ContentView` alert 可打開 `UserProfileView` sheet；`Later` 正常關閉 |
| S04 | 驗收與回歸 | QA | Spec Compliance Matrix 的測試至少覆蓋 P0 / reminder cadence 核心路徑 |

## Done Criteria

1. `DataSourceSelectionView` 有可用的 `稍後再設定` 路徑。
2. skip path 寫入後端與本地的 `data_source = unbound`，且不啟動 Garmin / Strava / Apple Health 授權。
3. onboarding 完成後的未綁定提醒仍走 `ContentView` 既有 alert，不新增第二套提醒 UI。
4. 未綁定提醒頻率為每 3 天最多一次；同 session 不重複。
5. `Go to Settings` 會真正打開 `UserProfileView`。
6. 至少以下測試從 FAIL 變 PASS：`AC-ONB-BIND-01a`、`01b`、`02a`、`03b`、`04a`、`04d`、`06a`、`06a-1`、`06b`。

## 風險與取捨

- `AuthenticationService` 仍會在 onboarding 完成後照常發 raw notification；這次只在 `AppViewModel` 做節流，優點是改動小，缺點是 notification 來源仍較粗。
- `Go to Settings` 改成直接開 `UserProfileView` sheet，會讓 alert 與 profile 入口耦合到同一個 view；但這正好符合本 spec 要求的單一補綁入口。
- 後綁完成後是否要顯示「重新整理訓練建議」CTA，本次不實作。
