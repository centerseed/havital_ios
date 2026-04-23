---
type: TD
id: TD-ios-analytics-p0
spec: SPEC-ios-analytics-p0
status: Draft
created: 2026-04-15
updated: 2026-04-22
---

# 技術設計：iOS P0 埋點實作

> 這份 TD 現在是 current-state reconciliation 記錄，不是新設計提案。目標是把現有 repo 的 analytics 行為、文件、測試證據對齊。

## 調查報告

### 已讀文件（附具體發現）

- `SPEC-analytics-event-tracking.md` — iOS P0 共 10 個事件：onboarding 5 + subscription 3 + retention 2。Backend P0 已完成（GA4AnalyticsService + 6 events on prod）。
- `SPEC-ios-analytics-p0.md` — 現在已改成 current-state 驗收文件；重點差異是 `onboarding_start` 只有 `source + campaign_id`，沒有 `ad_group_id`。
- `Core/Analytics/AnalyticsEvent.swift` / `AnalyticsService.swift` / `FirebaseAnalyticsServiceImpl.swift` — 現有型別安全 analytics pipeline，支援 `offer_type`。
- `Core/Analytics/AttributionManager.swift` — Apple Search Ads attribution 現況只穩定提供 `source` 與 `campaignId`。
- `Core/Infrastructure/AppStateManager.swift` — `app_open` 發送點；同時寫入 `subscription_status` / `data_source` user properties。
- `HavitalApp.swift` — `session_start` 發送點，發生在 app 從背景回到前景後的 `.active` 事件。
- `Features/Onboarding/Presentation/Coordinators/OnboardingCoordinator.swift` — `onboarding_start` / `onboarding_complete` 發送點。
- `Features/Onboarding/Presentation/ViewModels/OnboardingFeatureViewModel.swift` — `onboarding_target_set` 發送點。
- `Features/Subscription/Presentation/ViewModels/PaywallViewModel.swift` — `paywall_view` / `paywall_tap_subscribe` / `purchase_fail` 發送點，後兩者都帶 `offer_type`。
- `Core/DI/DependencyContainer.swift` + `Core/DI/AppDependencyBootstrap.swift` — analytics 服務已在 app bootstrap 中註冊。

### 搜尋但未找到
- `ad_group_id` 的穩定傳遞路徑 → 現有 iOS code 沒有發送這個欄位
- `selectedTargetTypeId` 的持久化 writer → 本 repo slice 沒看到穩定寫入點，`target_type` 目前屬 best-effort

### 我不確定的事
- 無新的技術不確定點；剩下的是文件對齊與測試證據補強

### 結論
可以拿來驗收 current implementation；不需要再開新的 `ad_group_id` 實作路徑。

---

## Spec Compliance Matrix

| AC ID | AC 描述 | 實作位置 | 狀態 |
|-------|--------|---------|------|
| AC-IOS-ANALYTICS-01 | AnalyticsService 封裝層 | `Core/Analytics/AnalyticsService.swift` + `Core/Analytics/FirebaseAnalyticsServiceImpl.swift` + `Core/Analytics/AnalyticsEvent.swift` | Code-reviewed |
| AC-IOS-ANALYTICS-02 | onboarding_start | `OnboardingCoordinator.swift` `trackOnboardingStart()` | Verified by test, with limitation |
| AC-IOS-ANALYTICS-03 | onboarding_garmin_connect | `GarminManager.handleCallback()` | Code-reviewed |
| AC-IOS-ANALYTICS-04 | onboarding_garmin_complete | `GarminManager` sync completion path | Code-reviewed |
| AC-IOS-ANALYTICS-05 | onboarding_target_set | `OnboardingFeatureViewModel` goal completion | Verified by test (beginner + race_run path) |
| AC-IOS-ANALYTICS-06 | onboarding_complete | `OnboardingCoordinator.completeOnboarding()` | Verified by test |
| AC-IOS-ANALYTICS-07 | paywall_view | `PaywallViewModel.trackPaywallView()` / `PaywallView.onAppear` | Verified by test |
| AC-IOS-ANALYTICS-08 | paywall_tap_subscribe | `PaywallViewModel.purchase()` | Verified by test (`offer_type` included) |
| AC-IOS-ANALYTICS-09 | purchase_fail | `PaywallViewModel.purchase()` failure path | Verified by existing tests (`offer_type` included) |
| AC-IOS-ANALYTICS-10 | app_open | `AppStateManager` → `.ready` transition | Verified by test |
| AC-IOS-ANALYTICS-11 | session_start | `HavitalApp.swift` applicationState `.active` | Code-reviewed |
| AC-IOS-ANALYTICS-12 | GA4 User Properties | `AppStateManager` + `FirebaseAnalyticsServiceImpl` + live state sinks | Partially verified (`subscription_status` / `data_source` / `target_type` verified; Garmin-related live updates remain code-reviewed) |

---

## Component 架構

```
Core/Analytics/                          ← 新建目錄
├── AnalyticsEvent.swift                 ← Event enum（型別安全）
├── AnalyticsService.swift               ← Protocol
└── FirebaseAnalyticsServiceImpl.swift   ← Firebase Analytics SDK 實作

觸發點（修改既有檔案）：
├── OnboardingCoordinator.swift          ← onboarding_start, onboarding_complete
├── OnboardingFeatureViewModel.swift     ← onboarding_target_set
├── GarminManager.swift                  ← onboarding_garmin_connect, onboarding_garmin_complete
├── PaywallView.swift                    ← paywall_view
├── PaywallViewModel.swift               ← paywall_tap_subscribe, purchase_fail
├── HavitalApp.swift                     ← session_start
└── AppStateManager.swift                ← app_open
```

### AnalyticsEvent enum 設計

```swift
enum AnalyticsEvent {
    // Onboarding
    case onboardingStart(source: String, campaignId: String?)
    case onboardingGarminConnect(success: Bool)
    case onboardingGarminComplete(hasHistory: Bool)
    case onboardingTargetSet(targetType: String, raceId: String?, distanceKm: Double?)
    case onboardingComplete(durationSeconds: Int)

    // Subscription
    case paywallView(trigger: String, trialRemainingDays: Int?)
    case paywallTapSubscribe(planType: String, offerType: String)
    case purchaseFail(errorType: String, offerType: String)

    // Retention
    case appOpen(daysSinceInstall: Int, subscriptionStatus: String)
    case sessionStart(sessionCountToday: Int)

    var name: String { ... }        // → "onboarding_start" etc.
    var parameters: [String: Any] { ... }  // → ["source": "organic"] etc.
}
```

### AnalyticsService Protocol

```swift
protocol AnalyticsService {
    func track(_ event: AnalyticsEvent)
    func setUserProperty(_ value: String, forName name: String)
}
```

### DI 注入策略

**Singleton（與 AppStateManager 同級）：**

OnboardingCoordinator、GarminManager、AppStateManager 都是 Singleton，無法透過 constructor injection。改用 property-based access：

```swift
// 方案：在 DependencyContainer 中註冊，各 singleton 透過 lazy resolve 取用
private var analyticsService: AnalyticsService {
    DependencyContainer.shared.resolve()
}
```

**PaywallViewModel（已有 Optional DI pattern）：**

```swift
init(trigger: PaywallTrigger, 
     subscriptionRepository: SubscriptionRepository? = nil,
     analyticsService: AnalyticsService? = nil) {
    self.analyticsService = analyticsService ?? DependencyContainer.shared.resolve()
}
```

---

## 介面合約清單

| 函式/API | 參數 | 型別 | 必填 | 說明 |
|----------|------|------|------|------|
| `AnalyticsService.track(_:)` | `event` | `AnalyticsEvent` | Yes | Fire-and-forget，不 throw |
| `AnalyticsService.setUserProperty(_:forName:)` | `value`, `name` | `String`, `String` | Yes | GA4 user property |
| `AnalyticsEvent.name` | — | `String` | — | computed，回傳 snake_case 事件名 |
| `AnalyticsEvent.parameters` | — | `[String: Any]` | — | computed，回傳事件參數 dict |

---

## DB Schema 變更

無。

## UserDefaults 新增 key

| Key | Type | 用途 |
|-----|------|------|
| `analytics_first_install_date` | `Date` | 計算 `days_since_install` |
| `analytics_session_count_today` | `Int` | 今日 session 計數 |
| `analytics_session_count_date` | `String` (yyyy-MM-dd) | session 計數的日期，跨日重置 |
| `analytics_onboarding_start_time` | `TimeInterval` | Onboarding 開始時間，計算 duration |

---

## Current-State Checklist

| # | 項目 | 狀態 | 說明 |
|---|------|------|------|
| C01 | AnalyticsService 基礎設施 | 已落地 | `AnalyticsEvent` / `AnalyticsService` / `FirebaseAnalyticsServiceImpl` 都在 repo |
| C02 | 10 個事件 | 已落地 | onboarding / subscription / retention 都有對應觸發點 |
| C03 | User Properties | 部分落地 | `subscription_status`、`data_source` 已在 app open 路徑寫入；`target_type` 為 best-effort |
| C04 | `ad_group_id` | 未落地 | current code 只發 `source + campaign_id` |

### 驗收重點

1. `onboarding_start` 的 current payload 是 `source + campaign_id`，不是 `ad_group_id`
2. `paywall_tap_subscribe` / `purchase_fail` 都帶 `offer_type`
3. `app_open` 與 `session_start` 都有清楚的 app-level trigger
4. 測試要能直接證明 onboarding / paywall / retention 的核心觸發

## Evidence Summary

- Explicit test evidence:
  - `OnboardingCoordinatorAnalyticsTests` 驗證 `onboarding_start`
  - `OnboardingCoordinatorAnalyticsTests` 驗證 `onboarding_complete`
  - `OnboardingFeatureViewModelTests` 驗證 `onboarding_target_set` 的 beginner + race_run path
  - `PaywallViewModelTests` 驗證 `paywall_view`、`paywall_tap_subscribe`、`purchase_fail`
  - `AppStateManagerAnalyticsTests` 驗證 `app_open` 與 `subscription_status` / `data_source` / `target_type` user properties
- Code-review only:
  - `onboarding_garmin_connect`
  - `onboarding_garmin_complete`
  - `session_start`

---

## Risk Assessment

### 1. 不確定的技術點
- `target_type` 目前屬 best-effort user property，因為本 repo slice 沒看到穩定寫入點
- `ad_group_id` 不在 current code path，且本次不再開新實作路徑

### 2. 替代方案與選擇理由
- **重用 FirebaseLoggingService** vs **新建 AnalyticsService** → 選新建。理由：FirebaseLoggingService 混合 Cloud Logging + Analytics 職責，且是 actor（async 呼叫）。Analytics 事件應是同步 fire-and-forget，不需要 actor isolation。
- **AnalyticsEvent 用 enum** vs **用 struct + static factory** → 選 enum。理由：case exhaustive check 確保所有事件都被處理，參數型別安全。

### 3. 需要用戶確認的決策
- 無（設計已基於 SPEC 和既有 codebase pattern）

### 4. 最壞情況與修正成本
- 如果 Firebase Analytics SDK 的 `logEvent` 在主執行緒造成 jank → 包一層 `DispatchQueue.global().async`。修正成本：改一行。
- 如果 GA4 事件參數超過 25 個 event-scoped 限制 → 刪減低優先參數。修正成本：改 enum parameters computed property。
