---
type: TEST
id: TEST-garmin-initial-backfill-guard
status: Draft
l2_entity: 運動數據接入
source_spec: SPEC-garmin-initial-backfill-guard
created: 2026-05-01
updated: 2026-05-01
---

# Test Design: Garmin Initial Backfill Guard

## 目標

驗證 Garmin backfill 只在安全的首次 coverage 狀態下自動觸發，重複 OAuth callback / 重連 / raw endpoint 重複區間不會再次打 Garmin，且所有拒絕或失敗都有可查根因的 structured log。

## P0 場景

### S1: iOS OAuth callback 不直接打 raw backfill
Given: Garmin OAuth callback 成功  
When: `GarminManager.handleCallback` 完成 data source sync  
Then: App 不呼叫 raw `POST /garmin/backfill`，只呼叫 `POST /garmin/backfill/ensure-initial`  
AC: AC-GARMIN-BF-01, AC-GARMIN-BF-02

### S2: ensure-initial 首次可啟動 backfill
Given: 使用者 Garmin connected，且沒有任何 Garmin coverage/backfill record  
When: `POST /garmin/backfill/ensure-initial` 被呼叫  
Then: 後端呼叫 Garmin API，回傳 `decision=started` 與 backfill id，並寫入 coverage/request record  
AC: AC-GARMIN-BF-04, AC-GARMIN-BF-06

### S3: ensure-initial 遇到已請求 coverage 不打 Garmin
Given: 使用者已有重疊 Garmin coverage record  
When: `POST /garmin/backfill/ensure-initial` 被呼叫  
Then: 後端不呼叫 Garmin API，回傳 `already_requested` 或等效 decision，並記錄 matched coverage  
AC: AC-GARMIN-BF-05, AC-GARMIN-BF-09

### S4: raw backfill endpoint 也受 coverage guard 保護
Given: raw `/garmin/backfill` request 與歷史 coverage 重疊  
When: request 抵達後端  
Then: 後端不呼叫 Garmin API，回傳既有 coverage/backfill 狀態或可理解錯誤  
AC: AC-GARMIN-BF-11

### S5: monitor 更新 coverage 完成狀態
Given: Garmin accepted 後 coverage 已是 requested/monitoring  
When: monitor 偵測到新 workouts 或 timeout_no_data  
Then: coverage 狀態可區分 with_data 與 no_data，並可由 status endpoint 讀出  
AC: AC-GARMIN-BF-07

### S6: structured logging 覆蓋所有 reject/fail
Given: backfill request 因 no_connection、invalid_range、overlap、Garmin 409/401 或 internal error 被拒絕/失敗  
When: 後端回 4xx/5xx 或 skip Garmin API  
Then: Cloud Logging 有 `event_type`、`uid`、`request_id`、`error_code`、`decision`、requested range；不得包含 token  
AC: AC-GARMIN-BF-08, AC-GARMIN-BF-10

### S7: iOS non-started decision 不阻斷使用者
Given: ensure-initial 回傳 `already_requested`、`already_has_data` 或 `in_progress`  
When: App 收到 response  
Then: 不顯示阻斷錯誤，不影響 OAuth 成功後的主流程  
AC: AC-GARMIN-BF-03

## P1 場景

### S8: raw endpoint 未重疊仍可工作
Given: raw `/garmin/backfill` request 未與任何 coverage 重疊  
When: Garmin API accepted  
Then: 後端回傳 backfill id 並寫入 coverage  
AC: AC-GARMIN-BF-12

## 驗收指令

Backend targeted:

```bash
.venv/bin/pytest tests/spec_compliance/test_garmin_initial_backfill_guard_ac.py -q
.venv/bin/pytest tests/integration/test_garmin_backfill_integration.py -q
```

iOS targeted:

```bash
xcodebuild test -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:HavitalTests/GarminInitialBackfillGuardACTests
```
