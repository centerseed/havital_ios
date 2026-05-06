---
type: SPEC
id: SPEC-garmin-initial-backfill-guard
status: Draft
ontology_entity: 運動數據接入
created: 2026-05-01
updated: 2026-05-01
---

# Feature Spec: Garmin Initial Backfill Guard

## 背景與動機

Garmin backfill 的主鏈路在 prod 已確認可運作：`/garmin/backfill` 曾成功觸發，Garmin webhook 後續讓 workouts 增加並完成 monitor。但 prod 近 7 天也出現多筆 `/garmin/backfill` 400，且 Cloud Logging 沒有記錄結構化原因。

根因風險是 Garmin backfill 不是可自由重跑的同步 API。只要請求區間與曾經請求過的 backfill 區間重疊，Garmin 端可能拒絕。現有 iOS `GarminManager.handleCallback()` 在任何 OAuth callback 成功後都會無條件觸發 onboarding backfill，會把首次綁定、重連、切回 Garmin、token 修復等不同情境混在一起。

本 spec 目標是保留首次綁定後的自動 backfill 價值，同時把「是否要打 Garmin」的決策搬到後端，並補齊 coverage guard 與 structured logging，讓重複觸發不再傷害使用者。

## 目標用戶

- 首次綁定 Garmin 的新用戶，需要系統自動請求可用歷史資料。
- 已經請求過 Garmin backfill 的既有用戶，不應因重新授權或重新設定流程而重複撞到 Garmin 限制。
- Support / 開發團隊，需要從 prod log 判斷 backfill 失敗根因。

## Spec 相容性

已比對：

- `SPEC-data-backfill-and-calendar-sync.md`：既有 AC-SYNC-03 要求 Garmin 同步可輪詢進度、已有 job 時不重複發任務；本 spec 將「曾經請求過的 coverage」納入更嚴格防重。
- `SPEC-onboarding-delayed-data-source-binding.md`：後續補綁成功後必須清楚說明同步是否開始；本 spec 不改 onboarding 完成條件，只改 Garmin OAuth 成功後的 backfill 觸發策略。
- `TD-onboarding-delayed-data-source-binding.md` / `TEST-onboarding-delayed-data-source-binding.md`：既有設計要求不重構 OAuth SDK；本 spec 只改 callback 後的 backfill decision，不改 OAuth 本身。

衝突：無。此 spec 是既有 delayed binding / data sync 規格的補強。

## 需求

### P0-1: Garmin OAuth 成功後不得由 App 直接無條件打 raw backfill

- **描述**：iOS 端不能自行判定首次綁定並直接呼叫 `/garmin/backfill`。OAuth 成功後，App 只能呼叫後端的初始 backfill guard endpoint，由後端以 durable state 決定是否需要真正向 Garmin 發 backfill request。
- **Acceptance Criteria**：
  - `AC-GARMIN-BF-01`: Given Garmin OAuth callback 成功, When App 完成 data source 更新, Then App 不直接呼叫 raw `POST /garmin/backfill`。
  - `AC-GARMIN-BF-02`: Given Garmin OAuth callback 成功, When App 需要啟動初始歷史資料同步判斷, Then App 呼叫後端 guard endpoint，例如 `POST /garmin/backfill/ensure-initial`。
  - `AC-GARMIN-BF-03`: Given guard endpoint 回傳 `already_requested`、`already_has_data` 或 `in_progress`, When App 收到 response, Then App 不把它當成失敗阻斷使用者流程。

### P0-2: 後端以 coverage record 作為「首次 backfill」唯一判斷來源

- **描述**：「首次」不得定義成第一次 OAuth callback，也不得依賴 App `UserDefaults`。後端必須以 Garmin backfill coverage / historical request records 判定是否已經請求過任何重疊區間。
- **Acceptance Criteria**：
  - `AC-GARMIN-BF-04`: Given 使用者沒有任何 Garmin backfill coverage 且 Garmin connected, When `ensure-initial` 被呼叫, Then 後端可建立最近 14 天 initial backfill request。
  - `AC-GARMIN-BF-05`: Given 使用者已有任一 Garmin backfill coverage 與欲請求區間重疊, When `ensure-initial` 或 raw backfill 被呼叫, Then 後端不得再次呼叫 Garmin API。
  - `AC-GARMIN-BF-06`: Given Garmin API 回 `202 Accepted`, When 後端建立 backfill record, Then 後端必須立即記錄該請求區間為 coverage 狀態 `requested` 或等效狀態。
  - `AC-GARMIN-BF-07`: Given backfill 後續收到 workout data 或超時無資料, When monitor 更新狀態, Then coverage 狀態必須可區分 `completed_with_data` 與 `completed_no_data` 或等效狀態。

### P0-3: Backfill 失敗與跳過必須可觀測

- **描述**：prod log 必須能直接分辨 400 是重疊、未連線、日期錯、Garmin 409/401、token 問題或內部錯誤，不得只留下 status code。
- **Acceptance Criteria**：
  - `AC-GARMIN-BF-08`: Given Garmin backfill request 被拒絕或失敗, When 後端回傳 4xx/5xx, Then Cloud Logging 必須可用 `event_type`、`uid`、`request_id`、`error_code` 查到結構化原因。
  - `AC-GARMIN-BF-09`: Given 請求區間與既有 coverage 重疊, When 後端跳過或拒絕 Garmin API call, Then structured log 必須包含 matched coverage 的 id、start/end、status。
  - `AC-GARMIN-BF-10`: Given Garmin API 回 409/401, When 後端處理錯誤, Then structured log 必須保留 Garmin response 類型與映射後的 `error_code`，但不得記錄 access token。

### P0-4: Raw `/garmin/backfill` 也必須受到 coverage guard 保護

- **描述**：即使未來仍有手動資料同步入口或 debug entry 直接呼叫 raw `/garmin/backfill`，後端也必須先查 coverage，不能只保護 `ensure-initial`。
- **Acceptance Criteria**：
  - `AC-GARMIN-BF-11`: Given raw `/garmin/backfill` request 的區間與歷史 coverage 重疊, When request 抵達後端, Then 後端回傳既有 coverage / backfill 狀態或可理解錯誤，且不呼叫 Garmin API。
  - `AC-GARMIN-BF-12`: Given raw `/garmin/backfill` request 未重疊且通過驗證, When Garmin API accepted, Then 回傳 backfill id 並寫入 coverage。

## 明確不包含

- 不改 Garmin OAuth 本身的授權流程。
- 不在本 spec 新增 Web 端賽事設定或課表生成能力。
- 不保證 Garmin 會立即送回所有歷史資料；系統只能請求並追蹤狀態。
- 不清除既有 workouts 或已完成 backfill records。

## 技術約束（給 Architect 參考）

- Garmin access token / refresh token 不得出現在任何 log。
- `HealthKit → Backend API → UI` 仍是 Apple Health 資料路徑；本 spec 不新增 HealthKit 直連 UI 資料捷徑。
- 後端 coverage guard 必須是 server-side durable state，不可只依賴 App 本地狀態。
- iOS OAuth callback 不可阻塞主流程等待 backfill 完整完成。

## 開放問題

- `ensure-initial` 的回傳 payload 最終欄位命名由 Developer 依現有 response pattern 決定，但必須包含 decision/status 與 backfill/coverage reference。
