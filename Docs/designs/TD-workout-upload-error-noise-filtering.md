---
type: TD
id: TD-workout-upload-error-noise-filtering
spec: SPEC-workout-upload-error-noise-filtering
status: Draft
created: 2026-04-17
updated: 2026-04-17
---

# 技術設計：Workout Upload Error Noise Filtering

## 調查報告

### 已讀文件（附具體發現）

- `Havital/CLAUDE.md` — 專案硬規則明寫 `NSURLErrorCancelled` 必須先過濾；cancelled task 不應被當成 failure。
- `Havital/Docs/specs/SPEC-dual-track-cache-and-background-refresh.md` — `AC-CACHE-03` 要求背景刷新失敗只能記錄日誌或非阻斷訊號，不能把既有可用流程打成錯誤主狀態。
- `Havital/Docs/specs/SPEC-data-backfill-and-calendar-sync.md` — 規格要求真正同步失敗時提供 error / retry，但未要求把鎖屏或取消視為 failure。
- `Havital/Docs/specs/SPEC-training-record-and-workout-detail.md` — 訓練記錄頁的錯誤需求只要求非離頁提示，未要求把可恢復 background upload 事件升級為 prod error。
- `Havital/Docs/specs/SPEC-profile-and-data-integration-management.md` — Apple Health 整合是受控入口，但沒有要求鎖屏時上報 prod error。
- `Havital/Docs/decisions/ADR-003-paywall-trigger-and-error-handling.md` — 既有 ADR 已採用 `cancelled` 不視為 failure 的原則。
- `Havital/Havital/Features/Workout/Domain/UseCases/WorkoutBackgroundManager.swift` — `checkAndUploadPendingWorkouts()` 外層 `catch` 將所有查詢失敗都記為 `check_upload_error` / `.error`；`fetchRecentWorkouts()` 沒有針對 protected data 分類。
- `Havital/Havital/Services/Integrations/AppleHealth/AppleHealthWorkoutUploadService.swift` — 詳細錯誤分析已對 cancellation short-circuit，但批次上傳層仍用 `localizedDescription.contains("cancelled")` 做脆弱判斷，可能留下誤報與重複 log。
- `Havital/Havital/Core/Infrastructure/HealthDataUploadManagerV2.swift` — 另一條 HealthKit 背景路徑已把 `Protected health data is inaccessible` 靜默處理，可作為 precedent。
- `Havital/Havital/Services/Deprecated/WorkoutV2Service.swift` — 目前只是 wrapper 與 error enum 定義；實際上傳責任在 `AppleHealthWorkoutUploadService`。

### 搜尋但未找到

- `UnifiedWorkoutManager.swift` — 目前 repo 無此檔，原始計劃中的路徑已過時。
- 與這次 logging fix 對應的既有 `SPEC` / `TD` / 專屬測試檔 — 無。

### 我不確定的事

- [未確認] prod 上觀察到的 `3 ERROR + 3 WARNING` 是否全部來自目前分支的同一條 upload call chain。
- [未確認] `HKError.errorAuthorizationDenied` 是否在所有裝置鎖屏場景都穩定可得；目前較可靠的判斷依據仍是 HealthKit domain + `Protected health data is inaccessible` 訊息。

### 結論

可以開始設計。

## Spec 衝突檢查

無衝突。現有 spec / ADR 都支持將可恢復的 cancellation / background skip 與真正 error 分離。

## Spec Compliance Matrix

| AC ID | AC 描述 | 實作位置 | Test Function | 狀態 |
|-------|--------|---------|---------------|------|
| AC-WORKOUT-LOG-01 | 鎖屏導致的 protected data 不上報為 ERROR | `Havital/Havital/Features/Workout/Domain/UseCases/WorkoutBackgroundManager.swift` | `test_ac_workout_log_01_device_locked_healthkit_skip_is_not_error` | STUB |
| AC-WORKOUT-LOG-02 | 真正 HealthKit 錯誤保留可觀測性 | `Havital/Havital/Features/Workout/Domain/UseCases/WorkoutBackgroundManager.swift` | `test_ac_workout_log_02_non_locked_healthkit_failures_still_report` | STUB |
| AC-WORKOUT-LOG-03 | `-999` 不分類為 invalid workout data / ERROR | `Havital/Havital/Services/Integrations/AppleHealth/AppleHealthWorkoutUploadService.swift` | `test_ac_workout_log_03_cancelled_upload_is_short_circuited` | STUB |
| AC-WORKOUT-LOG-04 | 非取消類網路與 API 錯誤維持上報 | `Havital/Havital/Services/Integrations/AppleHealth/AppleHealthWorkoutUploadService.swift` | `test_ac_workout_log_04_non_cancelled_errors_keep_reporting` | STUB |
| AC-WORKOUT-LOG-05 | 可恢復事件不重複上報 | `Havital/Havital/Features/Workout/Domain/UseCases/WorkoutBackgroundManager.swift` + `Havital/Havital/Services/Integrations/AppleHealth/AppleHealthWorkoutUploadService.swift` | `test_ac_workout_log_05_recoverable_events_do_not_duplicate_logs` | STUB |

Test stub file: `Havital/HavitalTests/SpecCompliance/WorkoutUploadErrorNoiseFilteringACTests.swift`

## Component 架構

### 1. Background check 分類層

- 檔案：`WorkoutBackgroundManager.swift`
- 責任：
  - 為 `fetchRecentWorkouts()` 或其上層 `catch` 增加「裝置鎖定 / protected data」短路判斷。
  - 將該類事件改成 `info` 或更低等級，並改用更精確訊息，例如 `Workout upload skipped: device locked`。
  - 對非鎖屏的 HealthKit 查詢失敗保留原有 error path。

### 2. Upload service 分類層

- 檔案：`AppleHealthWorkoutUploadService.swift`
- 責任：
  - 批次上傳層改用 `error.isCancellationError`，不再靠字串 `contains("cancelled")`。
  - cancellation 在單筆 / 批次 / 詳細分析層都走一致 short-circuit。
  - 避免同一筆 recoverable 事件在批次層與詳細分析層各打一筆 Cloud Logging。

### 3. 共用判斷策略

- 取消：統一使用 `Error.isCancellationError`
- 裝置鎖定：新增本地 helper，以 `NSError.domain == "com.apple.healthkit"` 或 `HKError` 搭配 `localizedDescription` 包含 `Protected health data is inaccessible` 為主
- 非取消的 URLError / HTTP 錯誤：維持現有 `isExpectedError(_:)` 與詳細分析

## 介面合約清單

| 函式/API | 參數 | 型別 | 必填 | 說明 |
|----------|------|------|------|------|
| `Error.isCancellationError` | — | `Bool` | — | 既有 helper，供 upload cancellation 統一短路 |
| `WorkoutBackgroundManager.isProtectedDataUnavailableError(_:)` | `error` | `Error` | Yes | 新增本地 helper，判斷是否為鎖屏 / protected data skip |
| `WorkoutBackgroundManager.checkAndUploadPendingWorkouts()` | — | `async` | — | 外層 `catch` 需根據錯誤類型決定 `info` / `error` |
| `AppleHealthWorkoutUploadService.uploadWorkouts(_:force:retryHeartRate:)` | `workouts`, `force`, `retryHeartRate` | `[HKWorkout]`, `Bool`, `Bool` | Yes | 批次 catch 需使用 cancellation helper，避免誤判與重複 log |
| `AppleHealthWorkoutUploadService.reportWorkoutUploadError(...)` | `workoutData`, `error` | 既有內部型別 | Yes | 詳細錯誤分析需與批次層保持一致，不對 cancellation 重複上報 |

## DB Schema 變更

無。

## 任務拆分

| # | 任務 | 角色 | Done Criteria |
|---|------|------|--------------|
| S01 | 補 executable docs / AC stubs / PLAN | Architect | 本文件、SPEC、PLAN、AC stubs 建立完成 |
| S02 | 實作 workout logging noise filter | Developer | 見下方 S02 Done Criteria |
| S03 | 驗收 AC 與回歸風險 | QA | 見下方 S03 Done Criteria |

### S02 Done Criteria

1. `WorkoutBackgroundManager.swift` 新增鎖屏 protected data 判斷，`check_upload_error` 對應事件不再送出 `.error` Cloud Logging。
2. 鎖屏 skip 的訊息要改成明確表達 deferred / device locked，不得再使用「檢查待上傳健身記錄失敗」這種誤導性訊息。
3. `AppleHealthWorkoutUploadService.swift` 批次上傳改用 `error.isCancellationError` short-circuit，不再用 `localizedDescription.contains("cancelled")`。
4. `NSURLErrorCancelled (-999)`、`URLError.cancelled`、`CancellationError` 不得被包成 `invalidWorkoutData` 或 `batch_upload_failed` / `workout_upload_error` 的 prod error。
5. 非取消類網路錯誤（至少 `.notConnectedToInternet`、`.timedOut`）與 HTTP / encoding / decoding 錯誤的現有上報能力不得被拿掉。
6. recoverable 事件在 background manager / upload service 的多層路徑中，Cloud Logging 最多留下一筆非 error 診斷訊息，不得重複上報。
7. 以下 AC test 必須從 FAIL 變 PASS：`AC-WORKOUT-LOG-01`、`AC-WORKOUT-LOG-02`、`AC-WORKOUT-LOG-03`、`AC-WORKOUT-LOG-04`、`AC-WORKOUT-LOG-05`。
8. 至少補齊 `Havital/HavitalTests/SpecCompliance/WorkoutUploadErrorNoiseFilteringACTests.swift` 的實作，讓測試可表達 device locked / cancellation / non-cancelled error 三類行為。

### S03 Done Criteria

1. 逐條驗證 `AC-WORKOUT-LOG-01` 到 `AC-WORKOUT-LOG-05` 對應的測試與程式碼。
2. 靜態確認沒有把所有 HealthKit 錯誤一刀切 silence。
3. 靜態確認沒有把非取消類 URLError 一起吞掉。
4. 若無法完整跑測試，需明確標示哪些驗證是未執行、哪些只是 code inspection。

## Risk Assessment

### 1. 不確定的技術點

- `HKError` 在裝置鎖定時的具體 error code 可能不穩定，因此需要用 message/domain 雙重判斷，不宜只依賴單一 enum case。
- 現有程式碼可測性有限，Developer 可能需要先抽出小型 helper 才能穩定覆蓋 unit tests。

### 2. 替代方案與選擇理由

- **方案 A：只在 Cloud Logging pipeline 過濾訊息**
  - 不選理由：會保留 app 內錯誤分類錯誤，且無法修正 `invalid_workout_data` 誤導。
- **方案 B：直接全域 silence 所有 HealthKit / URLError**
  - 不選理由：會吞掉真正授權問題、無網路、timeout 等真錯誤。
- **方案 C：在 iOS 端精準分類 device-locked 與 cancelled**
  - 選擇理由：最小改動，能直接改善 prod 訊噪比，又不影響真正錯誤可觀測性。

### 3. 需要用戶確認的決策

- 無。使用者已明確要求只修 iOS App 端 logging level / 錯誤分類，不改 backend。

### 4. 最壞情況與修正成本

- 若 device-locked 判斷過窄，仍會殘留少量噪音；修正成本是補強 helper 條件，低。
- 若判斷過寬誤吞真正 HealthKit 錯誤，會降低 observability；修正成本是縮小 short-circuit 條件並回補測試，中。

