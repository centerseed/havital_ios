---
type: REVIEW
plan: PLAN-remove-apiclient-shared
design: TD-remove-apiclient-shared
reviewer: Claude
created: 2026-04-24
status: PASS_WITH_MINOR_ISSUES
---

# Review Report: remove-apiclient-shared

## Verdict
**PASS WITH MINOR ISSUES**

核心目標（拆掉 `APIClient.shared`、修 demo token 分裂）達成。`xcodebuild` 未在本 review session 執行（依 /review 規範不動手修只審查）；下面的判定全部基於 git diff、static grep、TD/Plan 對照。建議進 merge 前跑一次 clean build + `APIClientRemovalACTests` + climate settings maestro smoke 作為 exit evidence。

## Scope

- Base: `f31eafc`（HEAD）
- Diff: 35 files changed, +452 / -668；`APIClient.swift` (410 行) 與 `EmailAuthService.swift` (63 行) 刪除。
- TD AC: AC-APIREF-01..05；對應 `HavitalTests/SpecCompliance/APIClientRemovalACTests.swift` 5 個 test。

## Issues Found

### 🔴 Blocking (must fix before merge)
_None._

### 🟡 Important (should fix)

- [ ] `Havital/Views/Settings/ClimateSettingsView.swift:158,219,247` — `ClimateSettingsRepository` protocol、`ClimateSettingsRepositoryImpl` class 與全部 DTO（`ClimateSettingsPayload` / `ClimateAdapterDisclosure` / `ClimateUISummary` 等 8 個 `private struct`）都被塞在 View 檔內。這違反 iOS CLAUDE.md「DTO in Data layer / RepositoryImpl in Data layer」與 TD Component 架構第 3 條（「Climate settings uses a repository-backed ViewModel」，並列出 `Features/Settings/Climate/{Data,Domain}/…` 三個獨立檔）。AC-APIREF-02 的 file-contains 檢查只比對字串「ClimateSettingsRepository」在 View 檔出現，目前技術上通過，但等同於把 Data/Domain artifacts 藏在 Presentation 檔案裡——下一位讀 code 的人會以為 Climate module 尚未做 Clean Architecture。建議搬到 `Havital/Features/ClimateSettings/{Domain/Repositories,Data/{Repositories,DataSources,Models}}/`（用「ClimateSettings」或「Climate」feature 命名，避免和 `Features/Settings` 這個尚不存在的 umbrella 產生誤解）。
- [ ] `Havital/Features/TrainingPlan/Domain/Repositories/HealthDailyRepository.swift:4` — Domain protocol 的 `fetchHealthDaily(limit:)` 回傳 `HealthDailyResponse`；該型別定義於 `Features/TrainingPlan/Data/Models/HealthDailyModels.swift:140`，是 Codable 的 snake_case DTO。iOS CLAUDE.md 明訂「Entity in Domain (no Codable — couples Domain to serialization format)」。正確作法：Domain 層回 `[HealthRecord]` (若 HealthRecord 已是 camelCase entity) 或新建 `HealthDailyResult` domain entity，Repository 內部做 DTO → Entity mapping。否則任何 API schema 改動都會 ripple 進 Domain。
- [ ] `Havital/Features/TrainingPlanV2/Presentation/Views/Components/WeekTimelineViewV2.swift:935-941,1167-1177` — 新增 `feelsLikeFootnote`（zh-TW/en/ja 三語文案）與對應 UI 渲染。和 APIClient 拆除無關聯。scope creep：本 plan 的 exit_criteria、TD AC、APIClientRemovalACTests 皆未涵蓋此改動。建議要嘛拆成另一支 PR（走 i18n/climate-UX spec），要嘛在 PR description 明列為「順帶 ship 的氣候文案補強」讓 reviewer 與 QA 知道要驗。
- [ ] `Havital/Services/Authentication/AuthenticationService.swift:389` — `self.demoIdToken = try? await authSessionRepository.getIdToken()`。此賦值發生在 `authRepository.demoLogin(...)` 剛把 token 寫入 `AuthSessionRepository` 之後；`try?` 會把任何 error 吃掉讓 `demoIdToken` 變 nil。legacy 代碼若仍讀 `AuthenticationService.demoIdToken`（舊 bug 本來就因此分裂），靜默 nil 會變成新失敗模式。兩個修法擇一：(1) 讓 `AuthRepository.demoLogin` 同時回 `(AuthUser, idToken)` 或把 idToken 放在 `AuthUser` / 一個 session envelope 裡，caller 直接拿；(2) 把 `AuthenticationService.demoIdToken` 也廢掉（搜一次是否還有讀者，有就統一改讀 `authSessionRepository.getIdToken()`）。目前兩層 token 真實來源都存在且各自維護，只是再走一次 roundtrip 讓它們暫時一致。

### 🟢 Minor (optional)

- [ ] `Havital/Features/TrainingPlan/Infrastructure/TrainingLoadDataManager.swift:15`、`Havital/Services/Integrations/AppleHealth/AppleHealthWorkoutUploadService.swift:15` — 透過 default-arg `= HealthDailyRepositoryImpl()` / `= WorkoutRepositoryImpl.shared` 取得依賴；其它 Repository 都走 `DependencyContainer.shared.resolve()`。建議一致化（`DependencyContainer` 補 register），否則單元測試無法用 DI 替換這兩個 Repository。
- [ ] `HavitalTests/SpecCompliance/APIClientRemovalACTests.swift:70-75` — `test_ac_apiref_05_build_and_smoke_evidence_recorded` 只檢查 `PLAN-remove-apiclient-shared.md` 含特定字串。這不構成「build & smoke evidence」——任何 plan 文案改動都能讓它通過/失敗，無法證明實際 build 與 smoke 有跑。建議補一個 completion report 文件（`Docs/reports/REPORT-remove-apiclient-shared.md` 或類似），把 `xcodebuild clean build` 結尾片段、climate settings maestro 結果、workout upload 實測日誌貼進去，test 去讀該 report 的必備段落。
- [ ] `Havital/Features/Workout/Data/DataSources/WorkoutRemoteDataSource.swift:89` — 原 `uploadWorkout(_ request: UploadWorkoutRequest)` 的 path 從 `/v2/workouts/upload` 改成 `/v2/workouts`。確認過 grep：目前沒有任何 caller 走 `UploadWorkoutRequest` 版本的 upload（僅 Mapper/Repository 內部），所以這條 contract 變動沒有實際影響；但 **backend v2 路由是 `POST /v2/workouts`**（`cloud/api_service/api/v2/workout.py:449`），`/v2/workouts/upload` 是個從來沒接上的死路。行為上這是 bug fix，但建議在 commit message / PR 描述顯式指出，避免 QA 認為是意外 drift。
- [ ] `Havital/Features/Workout/Data/DataSources/WorkoutRemoteDataSource.swift:105` — 新增的 `uploadWorkout(_ workoutData: WorkoutData)` 用 `JSONEncoder()` 直接 encode，沒走既有的 `parser`/`APIParser.encode`。其他 method 一致使用 parser 解 response，但 encode 路徑兩種都存在；小不一致，未來加 request-side middleware（例如自動加 correlation id）時會漏。
- [ ] `Havital/Services/Integrations/AppleHealth/AppleHealthWorkoutUploadService.swift:990-1005` — 新的 `HTTPError` 分支取代原 `NSError(domain: "APIClient")` 判斷；但同一 function 後面還保留一個 `else if let nsError = error as? NSError`，確保 non-HTTPError、non-URLError 的 NSError 仍被 log。這段留著是合理的（Firebase / 其它層的 NSError 還會冒上來），不過建議在註解說明「此分支已不會再收到 APIClient NSError，是 generic fallback」，避免下個讀者誤以為還有 APIClient 殘留路徑。

## AC Verification

| AC | 狀態 | 證據 |
|----|------|------|
| AC-APIREF-01 `APIClient` type/檔案移除 | ✅ | `grep -rn "APIClient\b" Havital/ --include="*.swift"` 無 match；`Havital/Services/APIClient.swift` 不存在 |
| AC-APIREF-02 call sites 改走 HTTPClient / Repository | ✅（有 🟡 scope 問題） | FirebaseLoggingService 改 HTTPClient；TrainingLoadDataManager 用 HealthDailyRepository；ClimateSettingsView ViewModel 經 ClimateSettingsRepository（但 repo 位置在 Presentation 檔，見 🟡#1）；Email ViewModels 三支皆改走 `AuthRepository` protocol |
| AC-APIREF-03 AppleHealth workout upload contract 保留 | ✅ | `WorkoutRemoteDataSource` 有 `/v2/workouts`、`/workout/summary/`；`AppleHealthWorkoutUploadService.uploadWorkoutData` 改 `workoutRepository.uploadWorkout(workoutData)`；retry 邏輯保留；cancellation 由既有 `isCancellationError` 保留；error handling 改走 `HTTPError` |
| AC-APIREF-04 legacy auth/error types 清除 | ✅ | `EmailAuthService` / `APINetworkError` / `APIErrorResponse` / `domain: "APIClient"` 四組 grep 皆無 match |
| AC-APIREF-05 build & smoke evidence | ⚠️ 未完成 | AC test 只檢查 plan 字串（見 🟢#2）；本 review 未跑 xcodebuild／maestro，建議 developer 在 merge 前補 evidence（見 Recommended Exit Checklist） |

## Compliance Check (iOS CLAUDE.md / architecture rules)

| 規則 | 結果 |
|------|------|
| ViewModel depends on Repository protocol | ✅（RegisterEmail/EmailLogin/VerifyEmail/ClimateSettings 皆 inject protocol） |
| Repository 不發 `CacheEventBus.publish` | ✅（grep `CacheEventBus.*publish` 在 Data/Domain layer 無 match；僅保留既有 `.register` / `.subscribe` pattern） |
| DTO 在 Data layer、Entity 在 Domain | ⚠️ 違反（見 🟡#1、🟡#2） |
| `@MainActor` on ViewModel、DI wiring | ✅（email VM 皆 `@MainActor` + `DependencyContainer.shared.resolve()`） |
| `.tracked(from:)` chaining on API calls | ⚠️ 未查每一筆；HTTPClient 底層的 tracking 機制未改動應沿用。建議 QA 驗 login / climate settings 的 trace 還能關聯回 ViewName |
| HealthKit → Backend → UI 流向 | ✅（workout upload 仍經 repository → HTTPClient → backend） |

## Demo Token 分裂根因是否真的修好

- **之前**：`APIClient.shared` 透過 `AuthenticationService.demoIdToken`（instance var）取 token；`HTTPClient` 透過 `AuthSessionRepository.getIdToken()`（UserDefaults persist）取 token。冷啟後 instance var 歸零，ClimateSettings（走 APIClient）401，但主訓練（走 HTTPClient）正常。
- **現在**：全部 HTTP 走 `HTTPClient`；`AuthRepositoryImpl.demoLogin` → `authSessionRepository.setDemoToken(idToken)` 持久化；`AuthenticationService.demoLogin` 改呼叫 `authRepository.demoLogin`，再用 `authSessionRepository.getIdToken()` 回寫 legacy `demoIdToken` 屬性（後者建議一併下架，見 🟡#4）。
- **驗證建議**：
  - Maestro `verify-climate-settings-wording.yaml`（已 check-in 為 untracked）跑 pass，截圖 climate 畫面不再出現 `AuthError 錯誤 3`。
  - 手動：demo login → 冷啟 app → 立即進熱適應 → 觀察 network 200；再主訓練 → 觀察 network 200。兩條路徑同一 token。

## Recommended Exit Checklist（給 Developer，merge 前）

- [ ] 把 ClimateSettings Repository 搬到獨立檔（🟡#1）；或明確決策不搬，在 TD/PLAN 裡記 decision（ADR/D5）。
- [ ] HealthDaily Domain protocol 回 Domain entity 而非 `HealthDailyResponse` DTO（🟡#2）。
- [ ] WeekTimelineView feels-like 文案拆 PR 或 PR 描述明列（🟡#3）。
- [ ] 決定是否保留 `AuthenticationService.demoIdToken` 欄位（🟡#4）。
- [ ] `xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` 綠燈，截圖貼 completion report。
- [ ] `APIClientRemovalACTests` 跑 pass。
- [ ] maestro `verify-climate-settings-wording.yaml` pass + 截圖。
- [ ] 手動或 maestro smoke workout upload（HealthKit new workout → 觀察 `POST /v2/workouts` 200 與 summary 200）；無 E2E 就在 completion report 明列為未覆蓋項。

## Summary

這是一次相當扎實的 tech-debt 清理：`APIClient.shared` 連帶 `EmailAuthService.shared` 整體下架，email auth 四條路徑（register / login / verify / resend）與 demo login 統一走 `AuthRepository` protocol；workout upload 改用既有 `WorkoutRepository`，避開 PLAN 初稿想新建 `Features/Workouts/` 的命名分裂；HTTPError 取代 `NSError(domain:"APIClient")` 的 code-smell。5 個 AC grep criteria 全部綠，AC 測試檔認真到會掃整個 `Havital/` 目錄。

主要遺憾是 ClimateSettings 的 Repository 與 DTO 被直接塞在 View 檔裡（`private protocol` / `private struct`），技術上通過 AC string-match，但實質違反 Clean Architecture layering——這是下一波 refactor 的首要目標。另外 HealthDailyRepository Domain protocol 回傳 Data DTO，以及 WeekTimelineView 的 feels-like 文案混入 PR，都是 scope/layering 邊界要收乾淨的地方。

整體 confidence：**中高**。只要跑一次 clean build + APIClientRemovalACTests + climate maestro smoke，搭配上面 exit checklist 就能安心 merge。

---

**Next step**：不在本 session 動手修。開 fresh session、讀這份 review-report、依 🟡 清單決定修哪些 / 哪些轉 follow-up plan。

---

## Addendum — Independent Second-Pass Review (2026-04-24)

Fresh session 重新跑 `/review 9aa5936e...` 的 independent verification。基於 git diff 同一版本（HEAD=`f31eafc`，35 files + 新增/修改的 untracked）重走 AC、architecture rules、upload 高風險路徑。Findings 大幅吻合上方原 review，結論同為 **PASS WITH MINOR ISSUES**。

### Confirmed findings（與上方一致）

- 🟡 ClimateSettings Repository/DTO 塞在 View 檔 — confirmed (`ClimateSettingsView.swift:154-219`).
- 🟡 `HealthDailyRepository` Domain protocol 回傳 Codable DTO — confirmed.
- 🟡 WeekTimelineView feels-like 文案 scope creep — confirmed.
- 🟡 `AuthenticationService.demoIdToken` 雙層 token 來源仍並存 — confirmed.
- 🟢 `/v2/workouts/upload` → `/v2/workouts` 靜默端點收斂 — confirmed，`WorkoutRemoteDataSource.swift:92`。雖然目前無 active caller（`.syncWorkout(` grep 僅 test harness no-op），但 override 建議文件化。
- 🟢 Default-arg DI bypass (`= HealthDailyRepositoryImpl()` / `= WorkoutRepositoryImpl.shared`) — confirmed.

### 額外發現（上方原 review 未特別指出）

- 🟡 **`AuthRepository` Domain protocol 直接回傳 DTO** — `Features/Authentication/Domain/Repositories/AuthRepository.swift:37-42` 新增的三個 method 回傳 `RegisterData` / `VerifyData` / `ResendData`；三者定義於 `Havital/Models/EmailAuthModels.swift` 皆是 `Codable` 的後端 response DTO。這跟 🟡#2 HealthDailyRepository 問題同構：Domain protocol 洩漏 Data layer 型別，任何後端 API schema 改動會 ripple 進 Domain。建議改回 Domain entity（例如 `EmailRegisterResult`，只保留 `message` 這類 UI 需要的欄位）並在 `AuthRepositoryImpl` 做 mapping。
- 🟢 **FirebaseLoggingService service-locator pattern** — `Services/Core/FirebaseLoggingService.swift:231` 在 method 內部用 `DependencyContainer.shared.resolve()` 取 `HTTPClient`，沒有 inject 到 init。這與其他 call sites（init-inject）不一致，也讓單元測試較難替換。建議改為 init-inject。
- 🟢 **AC-03 test 的 `/v2/workouts` 斷言有 false-positive 風險** — `APIClientRemovalACTests.swift:53` 用 `.contains(#""/v2/workouts""#)`，此字串同時是 `/v2/workouts/upload` 的 prefix；若未來有人誤把 POST 端點改成 `/v2/workouts/upload`，test 仍然會通過。考慮改成正則或 endpoint-enum 等更嚴格的斷言。

### Build / Runtime evidence

本 session 未再跑 `xcodebuild` 或 maestro（Review 規範不動 code 亦不重複 developer 交付證據）。Task `9aa5936e...` 的 handoff_events 記錄：
- `agent:developer → agent:qa`：clean build PASS、`APIClientRemovalACTests` PASS、`verify-climate-settings-wording` Maestro PASS。
- `agent:qa → human`：accepted。

### Verdict（addendum）

維持 **PASS WITH MINOR ISSUES**。原 review Recommended Exit Checklist 仍然完整；再加一項：**收斂 `AuthRepository` 三個 email 相關 method 的回傳型別**（改為 Domain entity，不回傳 DTO），和 HealthDailyRepository 一起做成一次 follow-up refactor。
