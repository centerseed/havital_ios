---
type: SPEC
id: SPEC-ios-analytics-p0
status: Draft
parent: SPEC-analytics-event-tracking
created: 2026-04-15
updated: 2026-04-15
---

# Feature Spec: iOS P0 埋點實作

## 背景與動機

SPEC-analytics-event-tracking 定義了 27 個事件，其中 iOS 端 P0 有 10 個事件需要實作。Backend P0 已完成（GA4AnalyticsService + 6 個事件已上 prod）。iOS 端是當前卡點——沒有 iOS 埋點，onboarding 漏斗、paywall 轉換率、留存曲線全部看不到。

六月開漏斗前必須上線。

## 目標

在 iOS 端透過 Firebase Analytics SDK 實作 P0 10 個事件，覆蓋三大追蹤場景：
1. **Onboarding 漏斗**（5 事件）— 廣告引流後的轉換率
2. **訂閱生命週期**（3 事件）— paywall 曝光到付費的轉換率
3. **留存信號**（2 事件）— D1/D7/D30 留存曲線

## 現有基礎設施

- `FirebaseLoggingService.swift` — 已有 `logEvent(_:parameters:)` 方法，底層呼叫 `Analytics.logEvent()`
- `Logger.firebaseEvent(_:parameters:)` — 便利方法，fire-and-forget wrapper
- Firebase Analytics SDK 已整合（`import FirebaseAnalytics`）
- Firebase UID 已作為 user_id（透過 `AuthenticationService`）

**問題**：現有 `FirebaseLoggingService` 混合了 Cloud Logging（Firestore 上傳）和 Analytics（GA4 事件）兩個職責。P0 埋點只需要 Analytics，不需要 Cloud Logging。

## 需求

### AC-IOS-ANALYTICS-01: AnalyticsService 封裝層

Given iOS app 啟動，
When 任何模組需要發送 analytics 事件，
Then 透過統一的 `AnalyticsService` protocol 發送，不直接呼叫 `Analytics.logEvent()`。

**參數規格**：
- Protocol 定義 `func track(_ event: AnalyticsEvent)` 
- `AnalyticsEvent` 為 enum，每個 case 對應一個事件，參數型別安全
- 實作類別內部呼叫 `Analytics.logEvent(name, parameters:)`
- Event naming：全小寫 + 底線，最長 40 字元
- Parameter naming：全小寫 + 底線

### AC-IOS-ANALYTICS-02: onboarding_start

Given 新用戶首次進入 Onboarding 畫面，
When `OnboardingCoordinator` 初始化且 `isReonboarding == false`，
Then 發送 `onboarding_start` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `source` | String | Yes | `"organic"` (MVP 先固定，後續接 Apple Search Ads attribution) |

### AC-IOS-ANALYTICS-03: onboarding_garmin_connect

Given 用戶在 Onboarding dataSource 步驟，
When 用戶點擊「連接 Garmin」按鈕，
Then 發送 `onboarding_garmin_connect` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `success` | Bool | Yes | Garmin OAuth 是否成功 |

**注意**：此事件在 OAuth 回調後發送，不是點擊時。`success` 反映實際連接結果。

### AC-IOS-ANALYTICS-04: onboarding_garmin_complete

Given 用戶 Garmin 連接成功，
When Garmin 歷史資料同步完成（或確認無歷史資料），
Then 發送 `onboarding_garmin_complete` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `has_history` | Bool | Yes | 是否有 Garmin 歷史訓練資料 |

### AC-IOS-ANALYTICS-05: onboarding_target_set

Given 用戶在 Onboarding 中選定目標類型，
When `OnboardingFeatureViewModel` 完成目標設定（goalType 選定 + 如果是 race_run 則 race 資訊也選定），
Then 發送 `onboarding_target_set` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `target_type` | String | Yes | `"race_run"` / `"maintenance"` / `"beginner"` |
| `race_id` | String | No | 選擇的賽事 ID（僅 race_run） |
| `distance_km` | Double | No | 目標距離（僅 race_run） |

### AC-IOS-ANALYTICS-06: onboarding_complete

Given 用戶完成 Onboarding 全流程，
When `OnboardingCoordinator.completeOnboarding()` 成功執行，
Then 發送 `onboarding_complete` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `duration_seconds` | Int | Yes | 從 `onboarding_start` 到完成的總秒數 |

**計算方式**：`OnboardingCoordinator` 在 init 時記錄 `startTime`，完成時計算 `Date().timeIntervalSince(startTime)`。

### AC-IOS-ANALYTICS-07: paywall_view

Given 用戶觸發付費牆（API 403 / trial 到期 / 功能鎖定 / 設定頁點擊），
When `PaywallView` 出現在螢幕上（`.onAppear`），
Then 發送 `paywall_view` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `trigger` | String | Yes | `"api_gated"` / `"trial_expired"` / `"feature_locked"` / `"resubscribe"` / `"change_plan"` |
| `trial_remaining_days` | Int | No | 試用期剩餘天數（無試用期則不傳） |

**來源**：`PaywallViewModel.trigger`（已有 `PaywallTrigger` enum）和 `trialDaysRemaining`。

### AC-IOS-ANALYTICS-08: paywall_tap_subscribe

Given 用戶在 Paywall 畫面，
When 用戶點擊「訂閱」按鈕（年繳或月繳），
Then 發送 `paywall_tap_subscribe` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `plan_type` | String | Yes | `"yearly"` / `"monthly"` |

**觸發點**：`PaywallViewModel.purchase(offeringId:packageId:)` 被呼叫時，在 `purchaseState = .purchasing` 之前。

### AC-IOS-ANALYTICS-09: purchase_fail

Given 用戶發起購買，
When 購買失敗（非用戶主動取消），
Then 發送 `purchase_fail` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `error_type` | String | Yes | 錯誤分類：`"payment_declined"` / `"network_error"` / `"store_error"` / `"unknown"` |

**注意**：用戶主動取消（`.cancelled`）不發送此事件——取消是正常行為，不是失敗。

### AC-IOS-ANALYTICS-10: app_open

Given 用戶冷啟動 App，
When App 進入 `ready` 狀態（`AppStateManager.currentState == .ready`），
Then 發送 `app_open` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `days_since_install` | Int | Yes | 安裝至今天數 |
| `subscription_status` | String | Yes | `"trial"` / `"active"` / `"expired"` / `"free"` |

**計算方式**：
- `days_since_install`：用 `UserDefaults` 記錄首次啟動日期，每次計算差值
- `subscription_status`：從 `SubscriptionStateManager.currentStatus` 取得

### AC-IOS-ANALYTICS-11: session_start

Given 用戶將 App 從背景帶回前景，
When `scenePhase` 從 `.background` 或 `.inactive` 變為 `.active`，
Then 發送 `session_start` 事件。

| Parameter | Type | Required | 說明 |
|-----------|------|----------|------|
| `session_count_today` | Int | Yes | 今日第幾次 session |

**計算方式**：用 `UserDefaults` 記錄今日 session 計數，跨日重置。

### AC-IOS-ANALYTICS-12: GA4 User Properties

Given 用戶登入後，
When user profile 載入完成，
Then 設定 GA4 user properties，讓所有事件可按這些維度切分。

| User Property | 值 | 設定時機 |
|---------------|---|---------|
| `subscription_status` | `"trial"` / `"active"` / `"expired"` / `"free"` | 每次 app_open + 訂閱狀態變更時 |
| `target_type` | `"race_run"` / `"maintenance"` / `"beginner"` | Onboarding 完成 + 更換目標時 |
| `data_source` | `"apple_health"` / `"garmin"` / `"unbound"` | 資料來源連接/變更時 |

## 明確不包含

- **Cloud Logging 整合** — P0 埋點只用 Firebase Analytics，不走 Firestore Cloud Logging
- **P1/P2 事件** — 本 spec 只涵蓋 P0 的 10 個事件 + user properties
- **GA4 看板** — 事件上線後另案設計
- **Apple Search Ads attribution** — `onboarding_start.source` MVP 先固定 `"organic"`，attribution 接入另案
- **A/B testing** — 不在本 spec 範圍

## 技術約束

1. **不阻塞主流程** — 事件發送失敗不影響 UI 或業務邏輯，fire-and-forget
2. **不在 Repository 層發送事件** — Repository 是被動資料存取，事件發送屬於 ViewModel/Coordinator 層
3. **AnalyticsService 透過 DI 注入** — ViewModel 依賴 protocol，不直接依賴 impl
4. **Event enum 型別安全** — 不使用 raw string，避免 typo 造成的事件遺失

## 事件總覽

| # | Event Name | 端 | 觸發位置 |
|---|-----------|---|---------|
| 1 | `onboarding_start` | iOS | `OnboardingCoordinator.init` |
| 2 | `onboarding_garmin_connect` | iOS | Garmin OAuth callback |
| 3 | `onboarding_garmin_complete` | iOS | Garmin sync completion |
| 4 | `onboarding_target_set` | iOS | `OnboardingFeatureViewModel` goal selection |
| 5 | `onboarding_complete` | iOS | `OnboardingCoordinator.completeOnboarding()` |
| 6 | `paywall_view` | iOS | `PaywallView.onAppear` |
| 7 | `paywall_tap_subscribe` | iOS | `PaywallViewModel.purchase()` |
| 8 | `purchase_fail` | iOS | `PaywallViewModel.purchase()` failure path |
| 9 | `app_open` | iOS | `AppStateManager.currentState == .ready` |
| 10 | `session_start` | iOS | `scenePhase` → `.active` |
