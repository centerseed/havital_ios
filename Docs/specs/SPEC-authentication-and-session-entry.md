---
type: SPEC
id: SPEC-authentication-and-session-entry
status: Draft
ontology_entity: authentication-session-entry
created: 2026-04-15
updated: 2026-04-16
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

## 技術約束（給 Architect 參考）

- 入口路由以 `ContentView` 的狀態判斷為準
- 認證真相來源以 `AuthenticationViewModel` / `AuthSessionRepository` 為準
- reviewer demo session 雖可能無 Firebase session，仍必須滿足與正式登入相同的入口切換結果
