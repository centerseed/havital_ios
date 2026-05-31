---
type: TD
id: TD-remove-apiclient-shared
plan: PLAN-remove-apiclient-shared
status: Draft
created: 2026-04-24
updated: 2026-04-24
---

# 技術設計：移除 APIClient.shared

## 調查報告

### 已讀文件（附具體發現）
- `Docs/plans/PLAN-remove-apiclient-shared.md` — 目標是刪除 `APIClient.shared`，讓 iOS HTTP 統一走 `HTTPClient` / Repository；明列 13 個 direct call sites 與 workout upload 是高風險 stage。
- `skills/governance/document-governance.md` — PLAN 不能直接取代 execution spec；dispatch 前 DESIGN/TD 必須有 `Spec Compliance Matrix` 與 `Done Criteria`。
- `skills/governance/task-governance.md` — task 需有 acceptance criteria；完成後進 review，QA 驗收後 confirm。
- `Havital/Services/Core/HTTPClient.swift` — `DefaultHTTPClient` 透過 `AuthSessionRepository.getIdToken()` 取 token，支援 demo token persist、401 refresh/retry、`HTTPError.notFound`/`HTTPError.httpError` 等錯誤分類。
- `Havital/Core/DI/DependencyContainer.swift` — core dependencies 已註冊 `DefaultHTTPClient.shared` for `HTTPClient.self`，可供 FirebaseLoggingService 與 DataSource 使用。
- `Havital/Services/APIClient.swift` — legacy client 用 `AuthenticationService.shared.getIdToken()`；同檔包含 `HealthRecord`、`HealthDailyResponse`、`APINetworkError`、`APIErrorResponse`，刪檔前需搬走仍需使用的 model。
- `Havital/Services/Integrations/AppleHealth/AppleHealthWorkoutUploadService.swift` — 目前直接 POST `/v2/workouts` 並 GET `/workout/summary/{id}`；另有 `NSError(domain: "APIClient")` HTTP error 判斷，遷移時不可破壞 retry/queue/cache/cancellation 路徑。
- `Havital/Features/Workout/Data/DataSources/WorkoutRemoteDataSource.swift` — 已有 `uploadWorkout(_:)`，但 path 目前是 `/v2/workouts/upload`；PLAN 要求與 AppleHealth 現有 `/v2/workouts` contract 對齊。
- `Havital/Features/Workout/Domain/Repositories/WorkoutRepository.swift` 與 `WorkoutRepositoryImpl.swift` — 已有 Clean Architecture repository，可擴充 `uploadWorkout(_:)` 與 `fetchWorkoutSummary(id:)` 給 AppleHealth 使用。
- `Havital/Features/Authentication/Data/DataSources/BackendAuthDataSource.swift` — 已有 `demoLogin` 經 `HTTPClient` 並帶 reviewer headers；可補 register/login/verify/resend。
- `Havital/Features/Authentication/Data/Repositories/AuthRepositoryImpl.swift` — demo login 已能存 `AuthSessionRepository` demo token；`signInWithEmail` 目前 placeholder，需實作或補 email auth methods。

### 搜尋但未找到
- `Docs/specs/SPEC-*APIClient*` / `Docs/designs/TD-*APIClient*` / `Docs/decisions/ADR-*APIClient*` → 無可執行規格。
- ZenOS active tasks 搜尋 `APIClient shared HTTPClient workout upload` → 無重複任務。

### 我不確定的事（明確標記）
- [未確認] AppleHealth 上傳自動化 E2E 是否已有穩定 Maestro flow；若沒有，本輪用 unit/static test + build + smoke 取代，並在 QA Verdict 標示未覆蓋的真實 HealthKit ingestion 風險。

### 結論
可以開始實作；本 TD 將 PLAN 的 exit criteria 補成 AC IDs 與 Done Criteria。

## AC Compliance Matrix

| AC ID | AC 描述 | 實作位置 | Test Function | 狀態 |
|-------|--------|---------|---------------|------|
| AC-APIREF-01 | 移除 `APIClient` type、字串、註解與 `Havital/Services/APIClient.swift` | `Havital/` | `test_ac_apiref_01_api_client_removed` | STUB |
| AC-APIREF-02 | FirebaseLoggingService、TrainingLoadDataManager、ClimateSettings、Email auth 改走 HTTPClient/Repository | `Havital/Services/Core`, `Havital/Features/TrainingPlan`, `Havital/Views/Settings`, `Havital/Features/Authentication` | `test_ac_apiref_02_call_sites_use_httpclient_or_repository` | STUB |
| AC-APIREF-03 | AppleHealth workout upload 改走 WorkoutRepository/RemoteDataSource 並保留 `/v2/workouts`、summary、retry/queue/cancellation/error handling | `Havital/Services/Integrations/AppleHealth`, `Havital/Features/Workout` | `test_ac_apiref_03_workout_upload_contract_preserved` | STUB |
| AC-APIREF-04 | 移除 `EmailAuthService`、`APINetworkError`、`APIErrorResponse` 殘留 | `Havital/` | `test_ac_apiref_04_legacy_auth_and_errors_removed` | STUB |
| AC-APIREF-05 | clean build 與 smoke/regression 驗證通過，未自動化 workout E2E 需留下 evidence | repo root | `test_ac_apiref_05_build_and_smoke_evidence_recorded` | STUB |

Test stub file: `HavitalTests/SpecCompliance/APIClientRemovalACTests.swift`

## Component 架構

1. Core HTTP remains `HTTPClient` / `DefaultHTTPClient`; callers decode through `APIParser` / `ResponseProcessor`.
2. TrainingPlan health daily uses a new `HealthDailyRepository` protocol and DataSource; models move out of `APIClient.swift`.
3. Climate settings uses a repository-backed ViewModel; the SwiftUI View no longer calls a client directly.
4. Workout upload uses existing `WorkoutRepository`; `WorkoutRemoteDataSource` owns POST `/v2/workouts` and GET `/workout/summary/{id}`.
5. Auth email endpoints move into `BackendAuthDataSource` and `AuthRepository`; ViewModels depend on `AuthRepository`.

## 介面合約清單

| 函式/API | 參數 | 型別 | 必填 | 說明 |
|----------|------|------|------|------|
| `HTTPClient.request` | `path`, `method`, `body`, `customHeaders` | `String`, `HTTPMethod`, `Data?`, `[String:String]?` | Yes | 唯一 HTTP transport；auth endpoint 不加 token，其他 endpoint 由 `AuthSessionRepository` 供 token |
| `HealthDailyRepository.fetchHealthDaily` | `limit` | `Int` | Yes | 讀 `/v2/workouts/health_daily?limit=` |
| `ClimateSettingsRepository.fetchSettingsContext` | — | — | Yes | 並行讀 user profile 與 climate metrics |
| `ClimateSettingsRepository.updateSettings` | `payload` | `ClimateSettingsPayload` | Yes | PUT `/users/{uid}/climate-settings` |
| `WorkoutRepository.uploadWorkout` | `request` | `UploadWorkoutRequest` | Yes | AppleHealth 上傳路徑，必須維持 `/v2/workouts` contract |
| `WorkoutRepository.fetchWorkoutSummary` | `id` | `String` | Yes | GET `/workout/summary/{id}`；legacy summary endpoint 保留 |
| `AuthRepository.registerEmail` | `email`, `password` | `String`, `String` | Yes | POST `/register/email` |
| `AuthRepository.loginEmail` | `email`, `password` | `String`, `String` | Yes | POST `/login/email`; 401 保留 email-not-verified 行為 |
| `AuthRepository.verifyEmail` | `oobCode` | `String` | Yes | POST `/verify/email` |
| `AuthRepository.resendEmailVerification` | `email`, `password` | `String`, `String` | Yes | POST `/resend/email` |

## DB Schema 變更

無。

## 任務拆分

| # | 任務 | 角色 | Done Criteria |
|---|------|------|--------------|
| S01 | 補 TD/TEST/AC stubs | Architect | 本文件、`Docs/tests/TEST-remove-apiclient-shared.md`、`APIClientRemovalACTests.swift` 建立 |
| S02 | 實作 APIClient removal | Developer | 下方 Developer Done Criteria 全部完成 |
| S03 | 驗收 build、grep、AC、smoke | QA | 下方 QA Done Criteria 全部完成 |

## Developer Done Criteria

1. `Havital/Services/APIClient.swift` 與 `Havital/Services/Authentication/EmailAuthService.swift` 刪除，Xcode project reference 同步移除。
2. `grep -rn "APIClient\b" Havital/ --include="*.swift"` 無 match，包含 type、NSError domain、註解、log 文案。
3. `grep -rn "EmailAuthService" Havital/ --include="*.swift"` 無 match。
4. `grep -rn "APINetworkError\|APIErrorResponse" Havital/ --include="*.swift"` 無 match。
5. Workout upload 不改成新模組；必須使用既有 `Features/Workout` repository，並保留 AppleHealth 原有 `/v2/workouts` payload 與 `/workout/summary/{id}` summary path。
6. `HTTPError.notFound` / `HTTPError.httpError` 等 HTTPClient error 取代 `NSError(domain: "APIClient")` 判斷；取消錯誤仍先過濾。
7. ViewModel 只依賴 Repository protocol，不依賴 repository impl；Repository 不觸碰 `CacheEventBus`。
8. `APIClientRemovalACTests.swift` 從 FAIL 變 PASS，並至少跑 targeted test/build；若 simulator/HealthKit E2E 無法完整自動化，Completion Report 要明列未驗證範圍。

## QA Scenario Matrix

| 場景 | Priority | AC IDs | 驗證方式 |
|------|----------|--------|----------|
| Legacy grep clean | P0 | AC-APIREF-01, AC-APIREF-04 | `rg` / XCTest static source inspection |
| Demo login token source | P0 | AC-APIREF-02 | demo login smoke；確認後續 HTTPClient caller 不 401 |
| Climate settings no AuthError 3 | P0 | AC-APIREF-02, AC-APIREF-05 | Maestro `verify-climate-settings-wording.yaml` 或手動 simulator |
| Workout upload contract | P0 | AC-APIREF-03 | code inspection + unit/static test；若可行跑 HealthKit upload smoke |
| Clean build | P0 | AC-APIREF-05 | `xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |

## Risk Assessment

### 1. 不確定的技術點
- [未確認] 真實 HealthKit workout upload E2E 是否能在當前 simulator 穩定產生 HKWorkout；需要 QA 先搜尋既有 flow，沒有就用最小 smoke + static/unit coverage。

### 2. 替代方案與選擇理由
- 方案 A：call sites 直接換 `DefaultHTTPClient.shared`。不選，會繼續讓 ViewModel/Service 直接碰 transport，違反現有 Clean Architecture。
- 方案 B：保留 `APIClient` 但改 token source。暫時止血但不符合 exit criteria，且留下雙 client 維護風險。
- 方案 C：按既有 Repository/DataSource 分層遷移。選擇此方案，符合 PLAN 與專案硬約束。

### 3. 需要用戶確認的決策
- 無。使用者已明確要求實現 PLAN 並注意 workout upload 回歸。

### 4. 最壞情況與修正成本
- 最壞情況是 workout upload payload path 被誤改導致訓練資料無法上傳；修正成本中高，需立即回復 `/v2/workouts` contract 並補 regression test。
- Auth 遷移若破壞 demo login，所有 simulator smoke 會被阻斷；修正成本中，需優先恢復 `AuthRepository.demoLogin` + `AuthSessionRepository.setDemoToken` 路徑。
