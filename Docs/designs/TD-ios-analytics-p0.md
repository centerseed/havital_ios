---
type: TD
id: TD-ios-analytics-p0
spec: SPEC-ios-analytics-p0
status: Draft
created: 2026-04-15
updated: 2026-04-15
---

# 技術設計：iOS P0 埋點實作

## 調查報告

### 已讀文件（附具體發現）

- `SPEC-analytics-event-tracking.md` — iOS P0 共 10 個事件：onboarding 5 + subscription 3 + retention 2。Backend P0 已完成（GA4AnalyticsService + 6 events on prod）。
- `SPEC-ios-analytics-p0.md` — 12 條 AC，定義了 AnalyticsService protocol、10 個事件、3 個 user properties。
- `Havital/Services/Core/FirebaseLoggingService.swift` — 混合 Cloud Logging + Analytics 職責。已有 `Analytics.logEvent()` 呼叫，但用於 error tracking，不是結構化事件追蹤。不應重用——職責不同。
- `Havital/Core/DI/DependencyContainer.swift` — Service Locator pattern。`register<P, T>(_ instance: T, forProtocol protocolType: P.Type)` + `resolve<T>() -> T`。ViewModel 透過 factory method 建立。
- `Havital/Features/Onboarding/Presentation/Coordinators/OnboardingCoordinator.swift` — **Shared Singleton**（`static let shared`），不走 DI。16 個步驟。有 `completeOnboarding()` 方法，已 publish `.onboardingCompleted` event。
- `Havital/Features/Onboarding/Presentation/ViewModels/OnboardingFeatureViewModel.swift` — 透過 `DependencyContainer.shared.makeOnboardingFeatureViewModel()` 建立。持有 5 個 repository protocol。目標選擇在 `loadTargetTypes()` / `selectTarget(_:)` 等方法。
- `Havital/Features/Subscription/Presentation/ViewModels/PaywallViewModel.swift` — Optional DI：`init(trigger:, subscriptionRepository: nil)` fallback 到 DI resolve。有 `PurchaseState` enum（idle/purchasing/success/failed）。`trigger` 是 `PaywallTrigger` enum。
- `Havital/Core/Infrastructure/GarminManager.swift` — Shared Singleton。`startConnection()` 開始 OAuth PKCE。`handleCallback(url:)` 處理回調。`isConnected` 狀態。
- `Havital/Core/Infrastructure/AppStateManager.swift` — Shared Singleton。4 phase init → `.ready`。`subscriptionStatus` published property。
- `Havital/HavitalApp.swift` — Scene lifecycle：`onChange(of: UIApplication.shared.applicationState)` 偵測前景回歸。`hasLaunched` flag 區分冷啟動 vs 熱啟動。Garmin OAuth callback 透過 `onOpenURL` 路由。

### 搜尋但未找到
- `docs/designs/TD-*analytics*` → 無（首次 iOS analytics 設計）
- `AnalyticsService` protocol → iOS codebase 中不存在

### 我不確定的事
- Garmin 歷史資料同步完成的確切 callback 位置 → 需要 Developer 在實作時確認 `GarminManager` 內部 flow [未確認]

### 結論
可以開始設計。

---

## Spec Compliance Matrix

| AC ID | AC 描述 | 實作位置 | 狀態 |
|-------|--------|---------|------|
| AC-IOS-ANALYTICS-01 | AnalyticsService 封裝層 | `Core/Analytics/AnalyticsService.swift` + `Core/Analytics/FirebaseAnalyticsServiceImpl.swift` + `Core/Analytics/AnalyticsEvent.swift` | STUB |
| AC-IOS-ANALYTICS-02 | onboarding_start | `OnboardingCoordinator.swift` init/navigate(to: .intro) | STUB |
| AC-IOS-ANALYTICS-03 | onboarding_garmin_connect | `GarminManager.handleCallback()` | STUB |
| AC-IOS-ANALYTICS-04 | onboarding_garmin_complete | `GarminManager` sync completion path | STUB |
| AC-IOS-ANALYTICS-05 | onboarding_target_set | `OnboardingFeatureViewModel` goal completion | STUB |
| AC-IOS-ANALYTICS-06 | onboarding_complete | `OnboardingCoordinator.completeOnboarding()` | STUB |
| AC-IOS-ANALYTICS-07 | paywall_view | `PaywallView.onAppear` 或 `PaywallViewModel.loadOfferings()` | STUB |
| AC-IOS-ANALYTICS-08 | paywall_tap_subscribe | `PaywallViewModel.purchase()` | STUB |
| AC-IOS-ANALYTICS-09 | purchase_fail | `PaywallViewModel.purchase()` failure path | STUB |
| AC-IOS-ANALYTICS-10 | app_open | `AppStateManager` → `.ready` transition | STUB |
| AC-IOS-ANALYTICS-11 | session_start | `HavitalApp.swift` applicationState `.active` | STUB |
| AC-IOS-ANALYTICS-12 | GA4 User Properties | `FirebaseAnalyticsServiceImpl` + 各觸發點 | STUB |

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
    case onboardingStart(source: String)
    case onboardingGarminConnect(success: Bool)
    case onboardingGarminComplete(hasHistory: Bool)
    case onboardingTargetSet(targetType: String, raceId: String?, distanceKm: Double?)
    case onboardingComplete(durationSeconds: Int)

    // Subscription
    case paywallView(trigger: String, trialRemainingDays: Int?)
    case paywallTapSubscribe(planType: String)
    case purchaseFail(errorType: String)

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

## 任務拆分

| # | 任務 | 角色 | Done Criteria |
|---|------|------|--------------|
| S01 | AnalyticsService 基礎設施 + 全部 10 事件 + User Properties | Developer | 見下方 |

### S01 Done Criteria

1. **新建 3 個檔案**：`AnalyticsEvent.swift`、`AnalyticsService.swift`、`FirebaseAnalyticsServiceImpl.swift`，放在 `Havital/Core/Analytics/`
2. **DI 註冊**：`DependencyContainer` extension `registerAnalyticsModule()`，在 app init 時呼叫
3. **10 個事件全部埋入正確位置**（見 Spec Compliance Matrix 的實作位置欄）
4. **3 個 User Properties** 在 `app_open` 和狀態變更時設定
5. **4 個 UserDefaults key** 正確初始化和使用
6. **不阻塞主流程**：所有 `track()` 呼叫都是 fire-and-forget
7. **不在 Repository 層**發送任何事件
8. **Clean build 通過**：`xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
9. **用戶主動取消購買（`.cancelled`）不發送 `purchase_fail`**
10. **AC-IOS-ANALYTICS-01 到 AC-IOS-ANALYTICS-12 全部滿足**

---

## Risk Assessment

### 1. 不確定的技術點
- Garmin 歷史資料同步完成的確切 callback 路徑需在實作時確認
- `onboarding_start` 的 `source` parameter MVP 固定為 `"organic"`，後續需接 Apple Search Ads attribution

### 2. 替代方案與選擇理由
- **重用 FirebaseLoggingService** vs **新建 AnalyticsService** → 選新建。理由：FirebaseLoggingService 混合 Cloud Logging + Analytics 職責，且是 actor（async 呼叫）。Analytics 事件應是同步 fire-and-forget，不需要 actor isolation。
- **AnalyticsEvent 用 enum** vs **用 struct + static factory** → 選 enum。理由：case exhaustive check 確保所有事件都被處理，參數型別安全。

### 3. 需要用戶確認的決策
- 無（設計已基於 SPEC 和既有 codebase pattern）

### 4. 最壞情況與修正成本
- 如果 Firebase Analytics SDK 的 `logEvent` 在主執行緒造成 jank → 包一層 `DispatchQueue.global().async`。修正成本：改一行。
- 如果 GA4 事件參數超過 25 個 event-scoped 限制 → 刪減低優先參數。修正成本：改 enum parameters computed property。
