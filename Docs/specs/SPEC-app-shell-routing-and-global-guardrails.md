---
type: SPEC
id: SPEC-app-shell-routing-and-global-guardrails
status: Approved
layer: architecture
owns: app 啟動後的入口路由（登入／onboarding／re-onboarding／訓練版本）與全域 guardrail 的呈現方式
ontology_entity: app-shell-routing-guardrails
created: 2026-04-15
updated: 2026-09-06
tasks: [T-0449]
---

# Feature Spec: App Shell、Routing 與全域 Guardrail

## 狀態

`Approved`：語義已拍板，但本檔尚未逐條回推 `file:line`，所以不是 `Implemented`。
2026-09-06 由 T-0449 升版（P-002 D4 使用者裁決要在這裡定「V1 帳號在 2.0 的去向」，
而治理規定 `Draft` 不得被引用為系統事實）。

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

### AC-SHELL-08: V1 帳號在 2.0 不被送回 V1 畫面，首頁給它重新設定目標的入口

2.0 的首頁對還在 V1 訓練版本的帳號，把今日課那一格換成「用 2.0 重新設定目標」——
一句說明加一顆按鈕，按下去開的是既有的 re-onboarding（`App2OnboardingContainerView(isReonboarding: true)`，
與設定頁「重設目標」同一條）。走完由後端把 `training_version` 寫成 v2，首頁自己刷新成 V2 課表。
判斷 V1 的順序：**profile 讀得到而且是 `v2` 就不是 V1，到此為止**（這一條否決掉下面兩個）；
否則 `/v2/plan/status` 回 404 且 body 的 `error` 是 `training_plan_not_found` 或
`no_active_training_plan`，或 profile 讀得到而它的 `training_version` 不是 `v2`，
任一成立就算 V1。其他失敗（別的 404、500、連線失敗、被取消）照舊顯示「暫時讀不到」，
不得說成要重新設定。

`v2` 之所以壓過那兩個 error code：後端讀不到 overview 與「真的沒有 overview」回同一個
404 body（`application/plan_status.py` 的 `load_overview` 走 `strict=False`），分不出來；
已經知道是 v2 的帳號還被叫去重設目標，等於把一次讀取失敗說成「你的計畫沒了」。

profile 讀不到時**仍然認那兩個 error code**——收掉它，V1 用戶只要 profile 讀失敗就回到
空白首頁，那正是這條 AC 要治的病。代價是「V2 帳號 ＋ profile 讀不到 ＋ 後端 overview 讀取
失敗」同時發生時會誤判一輪，所以再補一條：**重新設定入口只在該輪仍判定 V1 時才留著**；
下一輪判不出 V1（不是那兩個 code、版本也讀不到）就退回「暫時讀不到」，不得黏著不放。

驗法：`App2HomeViewModel.planStatusFailureOutcome(error:knownTrainingVersion:)` 對那兩個
error code（版本未知或非 v2 時）與「版本已知且非 v2」回 `.needsV2Setup`；對
`user_not_found`、500、非 JSON body、版本未知且不是那兩個 code、**以及那兩個 code 但版本
已知是 v2** 回 `.failed`。`App2HomeV1EntryTests` 另外從 view model 那一層驗
`todayState == .needsV2Setup`（V1 帳號的 404）、`todayState == .unavailable`
（V2 帳號的 500 與 V2 帳號的同一個 404），以及「不黏住」那條的兩半：先 `.needsV2Setup`，下一輪
**profile 讀得到而且是 `v2`** → 退回 `.unavailable`；下一輪**不是那兩個 code、版本也還是
讀不到** → 退回 `.unavailable`。

（2026-09-06 P-002 D4 使用者裁決：V1 用戶自助遷移，不做批次 migration、不回 V1 畫面。
AC-SHELL-04 的版本路由只管 1.x 殼；2.0 這條分支的去向由本條規定。）

## 明確不包含

- 各 tab 內部畫面的細節規格
- 訂閱方案文案與 paywall 視覺內容
- Garmin / HealthKit / DataSource 的底層整合技術細節
