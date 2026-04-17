---
type: SPEC
id: SPEC-app-shell-routing-and-global-guardrails
status: Draft
ontology_entity: app-shell-routing-guardrails
created: 2026-04-15
updated: 2026-04-15
---

# Feature Spec: App Shell、Routing 與全域 Guardrail

## 背景與動機

`ContentView` 已經承擔 app 啟動後的全域路由與警示責任：初始化 loading、登入、onboarding、re-onboarding、主 tab、V1/V2 訓練版本切換，以及健康權限、Garmin 斷線、資料來源未綁定、訂閱提醒等全域 guardrail。但這些規則目前散在 code 中，尚未有正式規格。

## 相容性

- 訂閱與 paywall 行為遵循 `Docs/specs/SPEC-subscription-management-and-status-ui.md`
- 訓練首頁行為遵循 `Docs/specs/SPEC-training-hub-and-weekly-plan-lifecycle.md`
- onboarding 路徑遵循 `Docs/specs/SPEC-onboarding-redesign.md`

## 需求

### AC-SHELL-01: App 啟動後必須先經過明確的入口狀態判斷

Given app 啟動後仍在初始化，  
When `AppStateManager` 尚未 ready，  
Then 系統必須先顯示 loading screen，而不是提早露出登入頁或主畫面。

### AC-SHELL-02: 未登入、未完成 onboarding、re-onboarding 必須走不同路徑

Given 使用者狀態改變，  
When `ContentView` 重新判斷入口，  
Then 未登入顯示 `LoginView`、首次使用顯示 `OnboardingContainerView(isReonboarding: false)`、re-onboarding 顯示 `OnboardingContainerView(isReonboarding: true)` 且直接取代 main content，不得再用 sheet 疊在主畫面上。

### AC-SHELL-03: 主 app 必須維持三個穩定的一級 tab

Given 使用者已登入且完成 onboarding，  
When 主畫面載入完成，  
Then 系統必須提供訓練、訓練紀錄、表現資料三個一級 tab，作為主要資訊架構。

### AC-SHELL-04: 訓練首頁必須透過版本路由決定 V1 或 V2

Given 使用者進入訓練 tab，  
When 系統尚未取得訓練版本，  
Then 畫面必須先顯示載入狀態；取得版本後再切到 `TrainingPlanView` 或 `TrainingPlanV2View`，不得同時初始化兩套訓練首頁。

### AC-SHELL-05: 全域警示必須是受控 guardrail，不得破壞主要上下文

Given app 偵測到健康權限不足、Garmin 斷線或資料來源未綁定，  
When 顯示警示，  
Then 系統必須在目前上下文上以 alert 顯示處置入口，讓使用者可前往設定、重新連接或稍後處理，而不是直接強制跳頁。

### AC-SHELL-06: 訂閱降級與提醒必須以非阻斷提示為主，必要時才進 paywall

Given `SubscriptionStateManager` 偵測到狀態降級或提醒條件成立，  
When `SubscriptionReminderManager` 產生提醒，  
Then 系統必須先顯示提醒 alert；只有在使用者點擊升級時，才以 sheet 方式打開 paywall。

### AC-SHELL-07: onboarding 與訓練版本切換後必須重新同步路由狀態

Given 使用者剛完成 onboarding、重置 onboarding 或離開 re-onboarding，  
When 入口狀態改變，  
Then app shell 必須重新檢查訓練版本與主要路由，避免停留在舊的 V1/V2 或 onboarding 上下文。

## 明確不包含

- 各 tab 內部畫面的細節規格
- 訂閱方案文案與 paywall 視覺內容
- Garmin / HealthKit / DataSource 的底層整合技術細節
