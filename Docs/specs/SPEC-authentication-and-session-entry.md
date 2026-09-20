---
type: SPEC
id: SPEC-authentication-and-session-entry
status: Approved
owns: iOS 冷啟動與登入／登出的入口路由語義——使用者在每一種認證與 onboarding 狀態下應該看到哪一個畫面
task: T-0749
layer: product
ontology_entity: authentication-session-entry
created: 2026-04-15
updated: 2026-09-20
---

# Feature Spec: Authentication 與 Session Entry

## 背景與動機

目前 app 的進入路由同時受 `AuthenticationViewModel`、`ContentView`、`LoginView` 與 onboarding 狀態控制。這些行為已在程式內存在，但缺少一份產品層規格定義「使用者打開 app 時應看到什麼」與「登入、登出、re-onboarding 如何切換」。

補充：reviewer demo account 的受控入口由 `SPEC-demo-reviewer-access-gate` 定義。本 spec 只定義 auth entry 主流程，不把 reviewer gate 當一般使用者可見入口。

## 範圍

- App 冷啟動與回到前景時的入口路由
- Google / Apple 正式登入入口與 reviewer demo 受控入口的產品邊界
- onboarding 未完成、已完成、re-onboarding 三種狀態切換
- 登出後的畫面與本地狀態清理

## 明確不包含

- 第三方 OAuth 技術細節
- email 註冊 / 驗證信流程
- RevenueCat 身分同步實作細節

## 需求

### AC-AUTH-01: 未登入用戶進入 Login 畫面

Given app 完成初始化且使用者未登入，  
When `ContentView` 決定入口畫面，  
Then 系統必須顯示 `LoginView`，不得短暫閃現主畫面或 onboarding 畫面。

### AC-AUTH-02: Login 畫面提供目前支援的正式登入入口

Given 使用者位於 `LoginView`，  
When 畫面載入完成，  
Then 系統必須提供 Google Sign-In、Apple Sign-In 兩個正式入口，並在請求進行中顯示 loading、禁止重複點擊。

### AC-AUTH-03: 登入失敗不得進入半登入狀態

Given 任一登入流程失敗或被取消，  
When Login 流程結束，  
Then app 必須留在 `LoginView`，顯示可理解的錯誤訊息，且不得把使用者帶進主畫面或標記為已完成登入。

### AC-AUTH-04: 已登入但未完成 onboarding 的用戶進入 onboarding

Given 使用者已通過登入且 `hasCompletedOnboarding == false`，  
When `ContentView` 決定入口畫面，  
Then 系統必須顯示 `OnboardingContainerView(isReonboarding: false)` 作為唯一主流程。

### AC-AUTH-05: 已完成 onboarding 的用戶進入主 app shell

Given 使用者已登入且 `hasCompletedOnboarding == true`，  
When app 進入主流程，  
Then 系統必須顯示包含訓練、訓練紀錄、表現資料三個 tab 的主 app shell。

### AC-AUTH-06: Re-onboarding 必須覆蓋主流程而非疊 sheet

Given 使用者已在主 app 內並觸發重新 onboarding，  
When `isReonboardingMode == true`，  
Then 系統必須以 `OnboardingContainerView(isReonboarding: true)` 取代主內容，避免與既有 sheet 或 tab 狀態衝突。

### AC-AUTH-07: 登出後必須回到乾淨的登入入口

Given 使用者目前已登入，  
When 使用者完成登出，  
Then app 必須清除目前使用者與 onboarding 狀態，並回到 `LoginView`，不得殘留先前的主畫面內容。

### AC-AUTH-08: Reviewer demo access 只能走受控 gate

Given build 需要提供 Apple reviewer 測試帳號，  
When reviewer 需要進入 demo session，  
Then 入口必須遵循 `SPEC-demo-reviewer-access-gate` 的受控流程，不得在 `LoginView` 預設顯示公開 Demo Login CTA。

### AC-AUTH-09: 問不到 onboarding 狀態時不得落進 onboarding

Given 使用者已登入，而 app 向後端確認 onboarding 狀態的那一次讀取失敗（連線失敗、逾時、5xx 都算），
When `ContentView` 決定入口畫面，
Then 本地已知這個帳號完成過 onboarding 時（快取的 `AuthUser`，或 `UserDefaults` 的
`hasCompletedOnboarding`），照本地已知進入主 app shell；本地不知道時必須顯示可重試的讀不到畫面，
**不得顯示 onboarding**。

- **為什麼**：onboarding 走完會用新的 overview 蓋掉使用者進行中的計畫。2026-09-18 Android 端
  因為同一類誤判，一位雙平台使用者的 24 週計畫在第 8 週被換成新的第 1 週，iOS 那台同時失效
  （T-0749）。iOS 目前擋得住「老用戶碰到一次失敗」，擋不住「重裝或清資料後又讀不到」。
- **現況**：判斷在 `AuthenticationViewModel.swift:178-200` 的 `resolveOnboardingStatus()`。
  它在問後端**之前**先算「本地知不知道」，且用 `UserDefaults.object(forKey:)` 而不是
  `bool(forKey:)`——`bool` 對「沒設定過」與「設定成 false」都回 false，把「問不到」跟
  「後端說沒完成」壓成同一個值，那正是本條要分開的兩件事。
  `fetchCurrentUserData()`（同檔 `:333-359`）回傳 `Bool`，明確報出這一次有沒有真的拿到資料；
  失敗時只記 `error`、不覆寫 `hasCompletedOnboarding`（同檔 `:354-357`）。
  畫面分流在 `ContentView.swift:116-145`，onboarding 那一格退到 `:146`。
  重試入口是 `retryOnboardingStatusResolution()`（`AuthenticationViewModel.swift:203-210`）。
- **不要誤用既有的重試畫面**：`Views/Components/AppLoadingView.swift:40-75` 那顆重試按鈕綁的是
  `AppStateManager.currentState`，不是這裡的 auth 讀取失敗，不能直接當成本條的出口。
  本條用的是 `Shared/Components/SharedErrorView.swift`，並加了 opt-in 的 `forceRetryEnabled`：
  這個畫面沒有別的出口，`isRetryable == false` 的錯誤（404／401）不能把使用者留在按不動的死畫面。
- **未涵蓋**：後端回 401（token 過期）但 Firebase 本機 session 仍有效時，本條會把人留在讀不到
  畫面重試；Android 的 AC-AND-94a 在同樣情況把人導去重新登入。兩端要不要一致尚未裁決。
- **未涵蓋（之二）**：`fetchCurrentUserData()` 的 in-flight guard（同檔 `:334-337`）在「已有另一次
  抓取進行中」時也回 `false`，而 `:185` 把這個 `false` 直接當成「沒確認到」。冷啟動有三個觸發點
  （`:169` init 的 Task、`:231` Firebase listener、`:278` CacheEventBus 訂閱），若 listener 那趟先
  進入 fetch，網路正常的新用戶也會算出 `onboardingStatusUnavailable == true`，停在讀不到畫面要按一次
  重試。`:169` 的 Task 先於 listener 註冊，所以機率低，且按重試即可自救——因此暫不修。要修的話是讓
  `fetchCurrentUserData()` 區分「失敗」與「被 guard 跳過」。
- **Android 對應**：`docs/specs/SPEC-android-app.md` 的 AC-AND-94a。兩端由使用者 2026-09-20
  一起裁決。
- **怎麼驗**：清掉 app 資料後登入一次、關掉 app、斷網冷啟，不得出現 onboarding；本地有旗標時
  斷網冷啟仍進主畫面。

## 技術約束（給 Architect 參考）

- 入口路由以 `ContentView` 的狀態判斷為準
- 認證真相來源以 `AuthenticationViewModel` / `AuthSessionRepository` 為準
- reviewer demo session 雖可能無 Firebase session，仍必須滿足與正式登入相同的入口切換結果
