---
type: SPEC
id: SPEC-onboarding-delayed-data-source-binding
status: Approved
ontology_entity: 訓練計畫系統
created: 2026-04-22
updated: 2026-04-22
---

# Feature Spec: Onboarding 延後綁定資料來源

## 背景與動機

目前 onboarding 的資料來源步驟把 Apple Health、Garmin、Strava 都當成第一輪就要完成的主要決策。這讓使用者在還沒看到課表價值前，就先碰到 Garmin / Strava OAuth 與整合判斷，增加第一輪流失風險。

產品目標已改成：先讓使用者完成 onboarding、生成第一版課表，再用 app 內非阻斷提醒，引導有需要的人後續補綁 Garmin / Strava。

這份 spec 的任務，是把這個改動的產品邊界講清楚：哪些資料來源屬於 onboarding 當下就要決定、`稍後再設定` 的正式語意是什麼、提醒何時出現、以及之後補綁後使用者應預期什麼變化。

## 目標用戶

1. 想先快速拿到第一版課表的新用戶
2. 有 Garmin 或 Strava，但不想在 onboarding 當下處理 OAuth / 權限的新用戶
3. onboarding 當下先用估算值或手動輸入，之後再補齊真實訓練資料的跑者

## 相容性

- onboarding 主流程與步驟脈絡遵循 `SPEC-onboarding-redesign.md`
- app shell 的全域 guardrail / non-blocking alert 原則遵循 `SPEC-app-shell-routing-and-global-guardrails.md`
- profile 內資料來源管理入口遵循 `SPEC-profile-and-data-integration-management.md`
- analytics `data_source` user property 與事件值沿用 `SPEC-ios-analytics-p0.md`，合法值包含 `unbound`

## 現況實作（已對齊 iOS）

1. `DataSourceSelectionView.swift` 目前只提供 `Apple Health`、`Garmin`、`Strava` 三選一，沒有 `稍後再設定`。
2. 使用者在 onboarding 選 `Garmin` 或 `Strava` 時，畫面會立刻先寫入 `updateDataSource(.garmin/.strava)`，然後直接啟動 `startConnection()` OAuth 流程。
3. `DataSourceType` 在 iOS 已有正式 `unbound` enum 值，不是新概念。
4. `AuthenticationService.checkDataSourceBinding(user:)` 目前會在 onboarding 完成後檢查後端 `data_source`；若是 `nil` 或 `unbound`，會發送 `dataSourceNotBound` 通知。
5. `ContentView` 已有 `showDataSourceNotBoundAlert`，按鈕語意是 `Go to Settings / Later`，代表 app 內「未綁定提醒」的 guardrail 已存在。
6. `UserProfileView` 的 data source section 已經支援 `unbound` 狀態提示，並能從 profile 內切換到 Apple Health / Garmin / Strava。

## 需求

### P0-1: Onboarding 必須允許在未綁 Garmin / Strava 的情況下完成並生成課表

- **描述**：Garmin / Strava 不得再是 onboarding 完成前的阻塞條件。使用者即使尚未完成任何外部整合，也必須能完成 onboarding 並取得第一版課表。
- **Acceptance Criteria**：
  - Given 使用者位於 onboarding 資料來源步驟, When 尚未綁定 Garmin 或 Strava, Then 系統仍提供可完成 onboarding 的主路徑，不因未綁定而卡住。
  - Given 使用者選擇「稍後再設定」, When 完成後續 onboarding 必填步驟, Then 系統必須成功生成第一版課表，而不是要求先完成 Garmin / Strava OAuth。
  - Given 使用者完成 onboarding 並進入訓練首頁, When 檢查 app 入口狀態, Then 使用者應被視為已完成 onboarding，而不是因資料來源未綁定被送回 onboarding。

### P0-2: `稍後再設定` 的正式語意必須是 `unbound`，不得用假資料來源掩蓋

- **描述**：`稍後再設定` 不是 Apple Health，也不是隱含 Garmin / Strava 將自動完成。系統必須以可追蹤的未綁定狀態保存，避免後續 routing、analytics 與設定頁誤判。
- **Acceptance Criteria**：
  - Given 使用者在 onboarding 選擇 `稍後再設定`, When 系統保存資料來源狀態, Then 正式狀態必須為 `unbound`。
  - Given 使用者目前狀態為 `unbound`, When App 設定 GA4 user property 或寫入使用者資料來源偏好, Then 不得寫成 `apple_health`、`garmin` 或其他假值。
  - Given 使用者為 `unbound`, When 進入 profile 或其他資料來源管理入口, Then 畫面必須顯示「尚未連接」或等效未綁定語意，而不是顯示某個已連接來源。

### P0-3: onboarding 內對 Garmin / Strava 的表達必須改成「可稍後補綁」，不是當下硬切 OAuth

- **描述**：onboarding 需要讓使用者知道 Garmin / Strava 之後仍可連接，但不能把第一次價值取得綁在外部授權流程上。
- **Acceptance Criteria**：
  - Given 使用者位於資料來源步驟, When 瀏覽可選項, Then 系統必須清楚表達 Garmin / Strava 可於 onboarding 後補綁。
  - Given 使用者尚未想處理 Garmin / Strava, When 點擊主要完成路徑, Then 不會像現況 `DataSourceSelectionView` 一樣立刻帶進 Garmin / Strava OAuth 或綁定判斷流程。
  - Given 使用者日後回看 onboarding 決策結果, When 查看資料來源狀態, Then 能理解自己目前是 `unbound`，且仍可補連接 Garmin / Strava。

### P0-4: 課表生成後必須以 app 內非阻斷提醒引導補綁 Garmin / Strava

- **描述**：提醒應出現在使用者已看見課表價值之後，而且是 app 內可略過的引導，不是新的 gate。
- **Acceptance Criteria**：
  - Given 使用者以 `unbound` 狀態完成 onboarding, When 第一次進入已完成 onboarding 的主 app 上下文, Then 系統必須沿用 `ContentView` 既有 alert 路徑顯示至少一個可感知的 app 內提醒，告知可補綁 Garmin / Strava 以提升後續訓練準確度。
  - Given 提醒已出現, When 使用者點擊「稍後再說」或關閉, Then 提醒消失且不影響當前課表使用。
  - Given 使用者在同一個 session 已關閉過提醒, When 再次回到前景或切換頁面, Then 同一 session 不得重複彈出相同提醒。
  - Given 使用者尚未綁定且先前已略過提醒, When 日後進入 `ContentView` 的 alert 或 `UserProfileView` 的 data source section, Then 仍有穩定入口可重新開始 Garmin / Strava 連接，不要求回到 onboarding。

### P0-5: 後續補綁成功後，系統必須提供清楚的同步與課表影響預期

- **描述**：使用者補綁 Garmin / Strava 後，最在意的是資料會不會補進來、現在的課表會不會壞掉、以及之後會不會更準。這些預期要在產品層先定義清楚。
- **Acceptance Criteria**：
  - Given 使用者在 onboarding 後完成 Garmin 或 Strava 綁定, When 連接成功, Then 系統必須明確告知是否開始同步歷史資料或進入後續同步流程。
  - Given 後續同步仍在進行中, When 使用者查看目前課表, Then 既有課表仍可正常使用，不因補綁流程被阻塞或清空。
  - Given 補綁後有新的歷史訓練資料進入系統, When 後續訓練分析、readiness 或下一輪課表調整發生, Then 系統可以使用這些新資料提高準確度，但不得把 onboarding 視為未完成。
  - Given 使用者剛完成後綁並看到同步完成結果, When 系統回報成效, Then 文案必須讓使用者理解這次補綁主要影響後續資料完整度與未來建議品質，而不是宣稱第一版課表當下已被無聲重算。

### P1-1: 提醒策略應避免過度打擾

- **描述**：補綁提醒的存在感要夠，但不能每次進 app 都重複打斷。
- **Acceptance Criteria**：
  - Given 使用者處於 `unbound` 且已離開 onboarding, When 系統決定再次顯示補綁提醒, Then 頻率必須為每 3 天最多一次，不得每次進 app 都顯示。
  - Given 使用者在 3 天冷卻期內多次開啟 app 或回到前景, When `ContentView` 檢查提醒狀態, Then 不得再次顯示未綁定提醒。
  - Given 使用者已成功綁定任一正式資料來源, When 重新進入 app, Then 與 `unbound` 相關的補綁提醒不得再出現。

### P1-2: 主 app 提醒與 profile 應共享一致的未綁定語意

- **描述**：提醒可以出現在不同 surface，但語意不能分裂成一邊叫未設定、一邊叫 Apple Health 預設。
- **Acceptance Criteria**：
  - Given 使用者為 `unbound`, When 分別查看主 app 內的未綁定提醒與 profile 資料來源區, Then 兩邊都必須表達為「尚未連接，可補綁 Garmin / Strava」的同一狀態。
  - Given 使用者從任一入口開始補綁, When 進入整合流程, Then 不需要回 onboarding 重走一次資料來源步驟。

## 明確不包含

- 不在本 spec 決定 Garmin / Strava OAuth 細節、callback 契約或後端 webhook / adapter 實作
- 不在本 spec 定義提醒元件的視覺稿、頁面切法或具體 UI component
- 不在本 spec 要求補綁成功後立刻強制重算目前課表
- 不在本 spec 改寫 Apple Health 當下 onboarding 的授權 / backfill 產品邏輯

## 技術約束（給 Architect 參考）

1. 既有 `data_source` / `data_source_preference` / analytics user property 已有 `unbound` 合法值；新流程必須沿用，不得自創平行狀態。
2. `ContentView` 已有「資料來源未綁定」alert guardrail；新提醒應沿用 non-blocking 原則，不可把未綁定重新做成 onboarding gate。
3. `UserProfileView` 已是資料來源管理的正式入口之一；後綁流程至少要能從主 app 提醒與 profile 任一入口開始。
4. onboarding 完成條件仍以課表成功建立為主，不得把 Garmin / Strava 綁定偷偷塞回完成判斷。
5. 提醒頻率建議沿用 `SubscriptionReminderManager` 的做法，用獨立 reminder manager + `UserDefaults` 記錄上次顯示時間；未綁定提醒的冷卻期為 3 天。

## 開放問題

1. 若使用者後綁的是 Garmin / Strava，其歷史資料同步完成後是否要提供「重新整理訓練建議」明示 CTA？本 spec 先不要求立即重算當前課表。

## AC ID Index

| AC ID | 對應需求 |
|------|----------|
| AC-ONB-BIND-01a | 未綁 Garmin / Strava 仍可完成 onboarding |
| AC-ONB-BIND-01b | 選擇稍後再設定仍可成功生成第一版課表 |
| AC-ONB-BIND-01c | `unbound` 完成 onboarding 後不被送回 onboarding |
| AC-ONB-BIND-02a | `稍後再設定` 正式保存為 `unbound` |
| AC-ONB-BIND-02b | analytics / preference 不得用假資料來源覆蓋 `unbound` |
| AC-ONB-BIND-02c | profile / 管理入口正確顯示未綁定狀態 |
| AC-ONB-BIND-03a | onboarding 明確表達 Garmin / Strava 可後綁 |
| AC-ONB-BIND-03b | 主要完成路徑不直接硬切 OAuth |
| AC-ONB-BIND-03c | 後續查看時能理解目前為 `unbound` |
| AC-ONB-BIND-04a | 完成 onboarding 後首次進入主 app 上下文時透過 `ContentView` alert 顯示非阻斷提醒 |
| AC-ONB-BIND-04b | 關閉提醒不影響使用 |
| AC-ONB-BIND-04c | 同 session 不重複彈相同提醒 |
| AC-ONB-BIND-04d | 主 app 提醒 / profile 保留穩定補綁入口 |
| AC-ONB-BIND-05a | 後綁成功後清楚說明同步是否開始 |
| AC-ONB-BIND-05b | 同步中既有課表仍可正常使用 |
| AC-ONB-BIND-05c | 新資料可改善後續分析與建議，但不影響 onboarding 完成狀態 |
| AC-ONB-BIND-05d | 同步完成文案不得宣稱第一版課表已被無聲重算 |
| AC-ONB-BIND-06a | 補綁提醒每 3 天最多一次 |
| AC-ONB-BIND-06a-1 | 3 天冷卻期內不得重複顯示未綁定提醒 |
| AC-ONB-BIND-06b | 一旦已綁定正式來源，不再顯示 `unbound` 補綁提醒 |
| AC-ONB-BIND-07a | 主 app 提醒與 profile 共用一致未綁定語意 |
| AC-ONB-BIND-07b | 任一入口都可直接開始補綁，不需回 onboarding |
