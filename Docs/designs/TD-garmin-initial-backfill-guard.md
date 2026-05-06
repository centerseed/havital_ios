---
type: DESIGN
id: TD-garmin-initial-backfill-guard
status: Draft
spec: SPEC-garmin-initial-backfill-guard.md
created: 2026-05-01
updated: 2026-05-01
---

# 技術設計：Garmin Initial Backfill Guard

## 調查報告

### 已讀文件（附具體發現）

- `docs/specs/SPEC-data-backfill-and-calendar-sync.md`：AC-SYNC-03 已要求 Garmin 歷史同步支援長時間處理與避免重複任務，但只描述已有處理中 job，沒有覆蓋 Garmin「曾經 backfill 過的區間不可重疊」限制。
- `docs/specs/SPEC-onboarding-delayed-data-source-binding.md`：P0-5 要求後續補綁成功後清楚說明是否開始同步，且不得阻塞既有課表；本設計維持非阻斷。
- `docs/designs/TD-onboarding-delayed-data-source-binding.md`：明確不重構 OAuth SDK / callback，本設計只移除 callback 後的 raw backfill 直打。
- `Havital/Core/Infrastructure/GarminManager.swift`：`handleCallback` 在 OAuth 成功與 data source 同步後，無條件呼叫 `BackfillService.shared.triggerOnboardingBackfill(provider: .garmin)`。
- `Havital/Features/Workout/Infrastructure/BackfillService.swift`：`triggerGarminBackfill(days:)` 直接打 `/garmin/backfill`，預設 14 天，僅對 429 做特殊處理，未處理 coverage/409 語意。
- `Havital/Views/UserProfileView.swift`：profile 切換到 Garmin 時總是啟動 OAuth，OAuth 成功後會落到同一個 `GarminManager.handleCallback`。
- `/Users/wubaizong/havital/cloud/api_service/api/v1/garmin_backfill.py`：raw endpoint 為 `POST /garmin/backfill`、`GET /garmin/backfill/list`、`GET /garmin/backfill/{backfill_id}`。
- `/Users/wubaizong/havital/cloud/api_service/domains/integrations/connect/garmin_backfill_service.py`：目前只檢查 active `monitoring` backfill overlap；completed/requested historical overlap 不會擋。
- `/Users/wubaizong/havital/cloud/api_service/core/database/repositories/garmin_backfill_repository.py`：`check_overlap` 只查 `status == monitoring`，沒有 durable coverage 查詢。
- Prod log 查詢：最近 24h 有一次 `/garmin/backfill` 成功並從 0 增至 14 workouts；最近 7 天有多筆 400，沒有 5xx，但 400 log 無 error body / error_code。

### 搜尋但未找到

- `docs/specs/` 中未找到專門定義 Garmin initial backfill coverage/idempotency 的 spec。
- iOS 中未找到 `ensure-initial` 或 server-side initial guard 呼叫。
- backend 中未找到獨立 Garmin coverage collection；目前 coverage 等同 backfill record，但查詢只看 monitoring。

### 我不確定的事

- [未確認] Garmin 對「曾經請求過的重疊區間」回傳固定是 409、429 或其他 4xx；設計要求後端映射並記錄實際 response 類型。

### 結論

可以開始設計與派工。需要同時修改 backend 與 iOS：backend 成為 initial backfill decision owner，iOS 停止 raw backfill 直打。

## AC Compliance Matrix

| AC ID | AC 描述 | 實作位置 | Test Function | 狀態 |
|---|---|---|---|---|
| AC-GARMIN-BF-01 | OAuth 成功後 App 不直接呼叫 raw `/garmin/backfill` | `GarminManager.handleCallback` | `test_ac_garmin_bf_01_callback_does_not_call_raw_backfill` | STUB |
| AC-GARMIN-BF-02 | OAuth 成功後 App 呼叫 guard endpoint | `BackfillService.ensureInitialGarminBackfill` | `test_ac_garmin_bf_02_callback_calls_ensure_initial` | STUB |
| AC-GARMIN-BF-03 | already/in_progress 類 response 不阻斷 App | `BackfillService` / `GarminManager` | `test_ac_garmin_bf_03_non_started_decision_is_non_blocking` | STUB |
| AC-GARMIN-BF-04 | 無 coverage 且 connected 時建立 initial backfill | `GarminBackfillService.ensure_initial_backfill` | `test_ac_garmin_bf_04_ensure_initial_starts_without_coverage` | STUB |
| AC-GARMIN-BF-05 | 有重疊 coverage 時不呼叫 Garmin API | `GarminBackfillRepository` / service guard | `test_ac_garmin_bf_05_overlap_coverage_skips_garmin_api` | STUB |
| AC-GARMIN-BF-06 | Garmin accepted 後立即記錄 coverage requested | `GarminBackfillService.trigger_backfill` | `test_ac_garmin_bf_06_accepted_writes_requested_coverage` | STUB |
| AC-GARMIN-BF-07 | monitor 可區分 with_data/no_data coverage 結果 | `_check_and_update_status` | `test_ac_garmin_bf_07_monitor_updates_coverage_completion_reason` | STUB |
| AC-GARMIN-BF-08 | 4xx/5xx 有 structured log | API exception handling | `test_ac_garmin_bf_08_rejection_logs_structured_reason` | STUB |
| AC-GARMIN-BF-09 | overlap log 帶 matched coverage | service guard | `test_ac_garmin_bf_09_overlap_log_contains_matched_coverage` | STUB |
| AC-GARMIN-BF-10 | Garmin 409/401 log 映射且不含 token | Garmin API error handling | `test_ac_garmin_bf_10_garmin_api_errors_logged_without_token` | STUB |
| AC-GARMIN-BF-11 | raw endpoint 也擋歷史重疊 coverage | `trigger_backfill` | `test_ac_garmin_bf_11_raw_backfill_blocks_historical_overlap` | STUB |
| AC-GARMIN-BF-12 | raw endpoint 未重疊 accepted 後寫 coverage | `trigger_backfill` | `test_ac_garmin_bf_12_raw_backfill_writes_coverage` | STUB |

## Component 架構

Backend:

- `api/v1/garmin_backfill.py`
  - 新增 `POST /garmin/backfill/ensure-initial`
  - raw endpoint 保持存在，但統一走 coverage guard。
- `domains/integrations/connect/garmin_backfill_service.py`
  - 新增 `ensure_initial_backfill(user_id, days=14)`
  - `trigger_backfill` 在 Garmin API 前檢查 historical coverage overlap。
  - 統一 structured log helper，所有 skip/reject/fail 都有 `event_type` + `error_code`。
- `core/database/repositories/garmin_backfill_repository.py`
  - 擴充 overlap 查詢：不限 monitoring，任何 requested/monitoring/completed 類狀態都可作為 coverage。
  - 可沿用 `backfill/garmin/items` 作為 coverage SSOT；若 Developer 判斷需要獨立 collection，必須保留舊 records 相容查詢。

iOS:

- `BackfillService`
  - 新增 `ensureInitialGarminBackfill(days:)`，呼叫 `/garmin/backfill/ensure-initial`。
  - response decision 為 `started / already_requested / already_has_data / in_progress / not_eligible` 類型時皆不阻斷 UI。
- `GarminManager.handleCallback`
  - 改呼叫 ensure-initial，不再 raw trigger `/garmin/backfill`。

## 介面合約清單

| 函式/API | 參數 | 型別 | 必填 | 說明 |
|---|---|---|---|---|
| `POST /garmin/backfill/ensure-initial` | `days` | int | 否 | 預設 14，上限 90；只做初始 backfill decision |
| `POST /garmin/backfill/ensure-initial` response | `decision` | string | 是 | `started` / `already_requested` / `already_has_data` / `in_progress` / `not_eligible` / `failed` |
| response | `backfill_id` | string/null | 否 | 有 started 或既有 job 時回傳 |
| response | `coverage` | object/null | 否 | 既有 coverage id/start/end/status |
| `POST /garmin/backfill` | `start_date` | string YYYY-MM-DD | 是 | raw manual/debug backfill |
| `POST /garmin/backfill` | `days` | int | 是 | 上限 90 |

## DB Schema 變更

優先不新增 collection，沿用 `backfill/garmin/items` 作為 coverage record，擴充欄位：

- `coverage_status`: `requested | monitoring | completed_with_data | completed_no_data | failed_retryable | failed_non_retryable`
- `coverage_start_timestamp`
- `coverage_end_timestamp`
- `decision`

若現有欄位 `start_timestamp` / `end_timestamp` / `status` 足以表達，Developer 可不新增欄位，但必須提供不限 `monitoring` 的 overlap 查詢與 completion 狀態區分。

## 任務拆分

| # | 任務 | 角色 | Done Criteria |
|---|---|---|---|
| S01 | Backend coverage guard + ensure-initial + logging | Developer backend | AC-GARMIN-BF-04~12 tests pass；raw endpoint historical overlap 不打 Garmin；所有 4xx/5xx 有 structured log |
| S02 | iOS callback 改走 ensure-initial | Developer iOS | AC-GARMIN-BF-01~03 tests pass；OAuth callback 不 raw hit `/garmin/backfill`；non-started decisions 不阻斷 |
| S03 | QA 驗收 | QA | 跑 backend/iOS AC tests，grep 實作，不 deploy |

## Done Criteria

1. Backend 新增 `POST /garmin/backfill/ensure-initial`，且只有後端可決定是否真正呼叫 Garmin API。
2. Backend raw `/garmin/backfill` 與 ensure-initial 都先查 historical coverage overlap。
3. Garmin accepted 後立即建立 durable coverage/request record；後續 monitor 更新 completed_with_data/no_data 或等效狀態。
4. 所有 backfill reject/fail/skip 都有 structured log，至少包含 `event_type`、`uid`、`request_id`、`error_code`、`decision`、requested range；overlap 帶 matched coverage；Garmin 409/401 不含 token。
5. iOS `GarminManager.handleCallback` 不再呼叫 raw `/garmin/backfill`，改呼叫 ensure-initial。
6. iOS 對 `already_requested`、`already_has_data`、`in_progress` 類 decision 不顯示阻斷錯誤。
7. 以下 AC tests 必須從 FAIL 變 PASS：AC-GARMIN-BF-01 ~ AC-GARMIN-BF-12。

## Risk Assessment

### 1. 不確定的技術點

- [未確認] Garmin 對 historical overlap 的實際 status code 不一定固定；因此要記錄原始 response 類型但不記 token。
- 既有 completed records 是否欄位完整可查，需要 Developer 在 backend repo 補讀 Firestore repository 與 integration tests。

### 2. 替代方案與選擇理由

- 選擇：server-side coverage guard。理由是 durable、跨裝置、跨重裝，能保護所有 caller。
- 不選：iOS `UserDefaults.hasBackfilled`。理由是換裝置/重裝會失效，且不能保護 Web/backend raw caller。
- 不選：完全移除首次自動 backfill。理由是第一次失敗代價高，新用戶需要歷史資料接入。

### 3. 需要用戶確認的決策

- 無。用戶已確認目標是最安全地減少 backfill 操作，且首次綁定仍應保留。

### 4. 最壞情況與修正成本

- 最壞情況：guard 誤判導致首次用戶沒有 backfill。修正成本中等，可透過 `decision` log 與 coverage 狀態定位並補 trigger。
- 次壞情況：coverage 判斷過鬆仍重打 Garmin。修正成本中等，需要擴充 overlap query 與 prod log 觀測。
