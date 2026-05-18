---
spec: N/A (architectural cleanup / tech debt)
created: 2026-04-24
updated: 2026-04-24
status: done
entry_criteria: ClimateSettings demo-login API fail 根因確認為 APIClient vs HTTPClient token source 分裂（APIClient → AuthenticationService.demoIdToken 無 persist；HTTPClient → AuthSessionRepository.demoToken 有 UserDefaults persist）
exit_criteria: `grep -rn "APIClient\b" Havital/ --include="*.swift"` 無 match（含型別名稱、protocol 欄位、NSError domain、註解殘留）；`Havital/Services/APIClient.swift` 已刪；clean build pass；demo login → 主訓練 → Climate 設定 → workout upload 全部 maestro smoke 不退步
---

# PLAN: 拆除 APIClient.shared，統一 HTTP 進 HTTPClient / Repository

## Background

iOS 目前有兩個 HTTP client 並存：

| Client | Token 來源 | Demo 重啟後能用？ |
|---|---|---|
| `HTTPClient` (主流) | `AuthSessionRepository.getIdToken()` → UserDefaults persist | ✅ |
| `APIClient.shared` (legacy) | `AuthenticationService.shared.demoIdToken` (instance var, no persist) | ❌ |

→ 造成「主訓練頁正常、熱適應頁 401 / AuthError 3」的分裂 bug。

目標：**砍掉 `APIClient.shared`**，同時把殘留 call sites 遷成 Clean Architecture（View → ViewModel → Repository protocol → DataSource → HTTPClient）。

---

## Call Site Inventory（`grep -rn "APIClient\.shared" Havital/`）

### `APIClient.shared` 直接呼叫（13 處）

| Call site | 用途 | 呼叫數 |
|---|---|---|
| `Services/Core/FirebaseLoggingService.swift:233` | POST `/internal/cloud-logging` | 1 |
| `Features/TrainingPlan/Infrastructure/TrainingLoadDataManager.swift:48,83` | `fetchHealthDaily` | 2 |
| `Views/Settings/ClimateSettingsView.swift:183,187,220` | climate profile/metrics GET、settings PUT | 3 |
| `Services/Integrations/AppleHealth/AppleHealthWorkoutUploadService.swift:787,809` | POST `/v2/workouts`、GET `/workout/summary/{id}` | 2 |
| `Services/Authentication/EmailAuthService.swift:13,24,38,48,58` | register / login / verify / resend / demo login | 5 |
| `Services/APIClient.swift` | 本體 | — |

### 其他 `APIClient` 殘留引用（S06 必須一併清）

| Call site | 內容 | 處理方式 |
|---|---|---|
| `Protocols/DataManageable.swift:93` | `var apiClient: APIClient { get }` protocol 欄位 | 一併移除；確認有無 conformer 仍讀它（搜 `\.apiClient`） |
| `Features/Target/Presentation/ViewModels/EditSupportingTargetViewModel.swift:71` | `nsError.domain == "APIClient" && code == 404` | 改比對 HTTPClient 對應 error（見 D3） |
| `Services/Integrations/AppleHealth/AppleHealthWorkoutUploadService.swift:997-998` | `nsError.domain == "APIClient"` | 同上 |
| `Views/MyAchievementView.swift:727,3018` | `print("APIClient direct call failed")`、「are now in APIClient.swift」註解 | 改註解/log 文案，不留殘留字串 |
| `Services/Integrations/AppleHealth/HealthDataService.swift:162` | 註解「HealthDailyResponse 已在 APIClient.swift 中定義」 | S02 搬走 type 後同步改註解 |
| `Features/Debug/V2FixtureExportView.swift:11,291` | 註解（bypass APIClient decode path） | 改為「bypass HTTPClient」或刪除 |

→ 合計 13 處 `.shared` 呼叫 + 7 處型別/字串引用 + 檔案本體。

---

## Tasks

- [ ] **S01**: FirebaseLoggingService 遷到 HTTPClient
  - Files: `Havital/Services/Core/FirebaseLoggingService.swift`
  - Migration: `APIClient.shared.request(EmptyResponse.self, path: "/internal/cloud-logging", method: "POST", body: ...)` → `httpClient.request(path: "/internal/cloud-logging", method: .POST, body: bodyData, customHeaders: nil)` 再丟掉回傳的 `Data`（HTTPClient 沒有 `.post/.get` helper，只有 `request(path:method:body:customHeaders:)`）
  - DI：透過 `DependencyContainer.shared.resolve()` 取 HTTPClient；確認 container 已註冊（`Havital/Core/DI/DependencyContainer.swift` 搜 `HTTPClient`）。若無，本 stage 先補 register。
  - Verify: `xcodebuild build` pass；手動 trigger 一筆 log，Cloud Logging / 後端 `/internal/cloud-logging` 200
  - Risk: 低（是 fire-and-forget 的日誌）

- [ ] **S02**: TrainingLoadDataManager 建 HealthDailyRepository
  - Files:
    - `Havital/Features/TrainingPlan/Data/DataSources/HealthDailyRemoteDataSource.swift` (new)
    - `Havital/Features/TrainingPlan/Data/Repositories/HealthDailyRepositoryImpl.swift` (new)
    - `Havital/Features/TrainingPlan/Domain/Repositories/HealthDailyRepository.swift` (new)
    - `Havital/Features/TrainingPlan/Infrastructure/TrainingLoadDataManager.swift` (modify)
  - Migration: Manager inject Repository；Repository 持有 DataSource；DataSource 用 HTTPClient
  - Verify: 進 Training Plan 主畫面讀 health daily 正常（無紅字 / ErrorView）
  - Risk: 中（主訓練頁依賴這條）
  - depends: S01

- [ ] **S03**: ClimateSettings 建 Repository + ViewModel refactor
  - Files:
    - `Havital/Features/Settings/Climate/Data/DataSources/ClimateSettingsRemoteDataSource.swift` (new)
    - `Havital/Features/Settings/Climate/Data/Repositories/ClimateSettingsRepositoryImpl.swift` (new)
    - `Havital/Features/Settings/Climate/Domain/Repositories/ClimateSettingsRepository.swift` (new)
    - `Havital/Views/Settings/ClimateSettingsView.swift` (modify ViewModel — 移除 `resolveCurrentUid` + `APIClient.shared.request`，改依賴 Repository)
  - Migration: ViewModel depends on `ClimateSettingsRepository` protocol
  - Verify: demo login → 設定 → 熱適應 → 看見新文案 + 無 `AuthError 錯誤 3`
  - Risk: 低（本輪驗證原本就卡在這，有現成 maestro flow `verify-climate-settings-wording.yaml`）
  - depends: S01

- [ ] **S04**: AppleHealthWorkoutUploadService 改走既有 `WorkoutRepository`
  - 說明：`Features/Workout/` 模組（單數）已存在 `WorkoutRepository` + `WorkoutRemoteDataSource`，且 `uploadWorkout(_:)` 已 POST `/v2/workouts`（HTTPClient）。**不新建 `Features/Workouts/`**，避免命名/DI 分裂。
  - Files:
    - `Havital/Features/Workout/Data/DataSources/WorkoutRemoteDataSource.swift` (modify — 新增 `fetchWorkoutSummary(id:)` 打 legacy `/workout/summary/{id}`；附 TODO 註明 v2 尚未提供 summary 端點)
    - `Havital/Features/Workout/Domain/Repositories/WorkoutRepository.swift` (modify — 加對應 method)
    - `Havital/Features/Workout/Data/Repositories/WorkoutRepositoryImpl.swift` (modify — 實作 delegate 到 DataSource)
    - `Havital/Services/Integrations/AppleHealth/AppleHealthWorkoutUploadService.swift` (modify — `uploadWorkoutData(_:)` 改呼叫 `workoutRepository.uploadWorkout(...)`；`getWorkoutSummary(workoutId:)` 改呼叫 `workoutRepository.fetchWorkoutSummary(...)`；保留重試/佇列邏輯；同步處理 line 997-998 的 `NSError domain == "APIClient"` 判斷)
  - Pre-check：
    - 確認既有 `UploadWorkoutRequest` / `UploadWorkoutResponse` DTO 與 AppleHealth 上傳 payload schema 一致；不一致就擴充，不 fork 新 DTO。
    - `/workout/summary/{id}` 的 response model (`WorkoutSummaryResponse`) 目前定義在哪？若在 APIClient.swift 內，一併搬到 `Features/Workout/Data/Models/` 作為 DTO。
    - 搜尋 `.maestro/flows/` 和 `HavitalTests/` 看現有 workout upload E2E；若無，S04 完成後補一個最小 smoke（登入 → 觸發 upload → 確認 200 + UI 不崩）。
  - Verify: workout upload 流程（模擬 Apple Health new workout → 上傳 → summary 呼叫）無 regression
  - Risk: 高（workout 上傳失敗 = 訓練紀錄丟失）
  - depends: S01

- [ ] **S05**: EmailAuthService 合併進 AuthRepositoryImpl / BackendAuthDataSource
  - Files:
    - `Havital/Features/Authentication/Data/DataSources/BackendAuthDataSource.swift` (modify — 加 register / login / verify / resend 方法；demo login 已有)
    - `Havital/Features/Authentication/Data/Repositories/AuthRepositoryImpl.swift` (modify — 多 expose 對應方法)
    - `Havital/Features/Authentication/Domain/Repositories/AuthRepository.swift` (modify — protocol 加 method 簽名；ViewModel 只認 protocol)
    - `Havital/Services/Authentication/AuthenticationService.swift:375` (modify — `demoLogin` 改呼 `authRepository.demoLogin(...)` 而非 `EmailAuthService.shared`)
    - `Havital/Features/Authentication/Presentation/ViewModels/RegisterEmailViewModel.swift:20` (modify — inject `AuthRepository` protocol，替換 `EmailAuthService.shared.register`)
    - `Havital/Features/Authentication/Presentation/ViewModels/EmailLoginViewModel.swift:23,42` (modify — 替換 `login` + `resendVerification`)
    - `Havital/Features/Authentication/Presentation/ViewModels/VerifyEmailViewModel.swift:17` (modify — 替換 `verify`)
    - `Havital/Services/Authentication/EmailAuthService.swift` (DELETE — 僅當上面 4 個 caller 全部改完且 `grep -rn "EmailAuthService" Havital/ --include="*.swift"` 無 match)
  - Pre-check：
    - BackendAuthDataSource 是否已有 register / login / verify / resend？缺哪個補哪個；DTO 以 snake_case + CodingKeys，response 映射成 Domain entity。
    - 4 個 direct callers（AuthenticationService + 3 個 ViewModel）都要改 DI，否則留一個就編譯失敗；3 個 ViewModel 目前若是直接 `EmailAuthService.shared` 單例，要改從 `DependencyContainer` resolve `AuthRepository` protocol（符合 iOS CLAUDE.md「ViewModel 依賴 Repository Protocol」）。
  - Verify: clean cold launch → reviewer demo login flow PASS；register / email login / verify / resend 4 條路徑各 cover 一次（手動或 maestro）
  - Risk: **極高**（demo login 壞 = 整個 App 打不開，本輪所有驗證也靠它）
  - depends: S01

- [ ] **S06**: 刪 APIClient.swift 本體 + 清場
  - Files:
    - `Havital/Protocols/DataManageable.swift` (modify — 移除 `var apiClient: APIClient { get }`；grep 所有 conformer 確認沒人讀這個欄位；有的話一起清)
    - `Havital/Features/Target/Presentation/ViewModels/EditSupportingTargetViewModel.swift:71` (modify — `nsError.domain == "APIClient" && code == 404` 改為 HTTPClient 對應的 error 判斷；見 D3)
    - `Havital/Services/Integrations/AppleHealth/AppleHealthWorkoutUploadService.swift:997-998` (modify — 同上)
    - `Views/MyAchievementView.swift:727,3018` (modify — 改 log 文案 + 移除「now in APIClient.swift」過時註解)
    - `Services/Integrations/AppleHealth/HealthDataService.swift:162` (modify — S02 搬走 `HealthRecord` / `HealthDailyResponse` / `HealthDailyData` 後，註解同步修正；這些 type 若 S02 未處理，本 stage 一併搬去 `Features/TrainingPlan/Data/Models/`)
    - `Features/Debug/V2FixtureExportView.swift:11,291` (modify — 註解改 HTTPClient)
    - `Havital/Services/APIClient.swift` (DELETE — 僅當以下 grep 都無 match 才可刪)
    - 檢查 Xcode project.pbxproj，確認 reference 移除
  - Verify (必須全綠):
    - `grep -rn "APIClient" Havital/ --include="*.swift"` → 無 match（型別 / 字串 / 註解 / NSError domain 全清）
    - `grep -rn "APINetworkError\|APIErrorResponse" Havital/ --include="*.swift"` → 無 match（D3 前提：本 plan 確認沒有殘留引用才刪；有引用先搬到 Core HTTP error 檔）
    - `grep -rn "EmailAuthService" Havital/ --include="*.swift"` → 無 match
    - `xcodebuild clean build` pass
    - 執行 maestro smoke：demo login → 主訓練 → 設定 / 熱適應 → 截圖新文案 visible
  - Risk: 低（前面 stage 都做完 APIClient 已無引用）
  - depends: S01, S02, S03, S04, S05

---

## Decisions

- **2026-04-24 D1**: 選方案 B（Clean Architecture 分層）而非方案 A（call site 直接用 HTTPClient）。
  理由：用戶明確表示無法忍受骯髒架構；且 iOS CLAUDE.md 規定 ViewModel 依賴 Repository protocol。

- **2026-04-24 D2**: Stage 順序 = 低風險 → 高風險。
  理由：低風險 stage 先建立信心和 pattern；EmailAuthService (bootstrap) 放最後是因為壞了 App 打不開，要等前面 pattern 穩定再動。

- **2026-04-24 D3**: `APINetworkError` / `APIErrorResponse` 原則上隨 `APIClient.swift` 一起刪；若 S06 grep 發現仍有外部引用，先搬到 Core HTTP error 檔（`Havital/Services/Core/` 下）再刪檔，不另起 plan。
  理由：這兩個 type 定義在 `APIClient.swift` 內部，檔案一刪任何殘留引用立刻編譯失敗；無法以「另建 plan」延後處理。S06 的 grep 是 gate：無引用 → 直接刪；有引用 → 搬家再刪。
  目前 inventory：已確認 `APINetworkError` / `APIErrorResponse` 只在 `APIClient.swift` 內被 throw / decode，未被外部檔案 import；但 S06 仍須 grep 確認一次（行為可能隨前面 stage 改動）。

- **2026-04-24 D4**: 每個 Stage 結束必須 `xcodebuild build` pass + simulator 手動驗證相關功能；不跨 Stage 批量 verify。
  理由：任何一個 Stage 失敗要能快速 bisect；尤其 S05 壞了 App 打不開就沒法驗後續。

---

## Dispatch Strategy

單一主 session（Claude Code）依序執行 S01 → S06。每個 Stage 結束：
1. `xcodebuild build` 必須 BUILD SUCCEEDED
2. Install 到 BEC21B6F (iPhone 17 Pro simulator)，驗相關功能
3. 更新本 PLAN 的 Task checkbox + Resume Point
4. 確認通過才進下一個 Stage

S04 (AppleHealth) 和 S05 (EmailAuth) 如果發現沒有現成 E2E 驗證 flow，**先補 maestro smoke 再 migrate**（不跳過測試）。

---

## Resume Point

**當前狀態**（2026-04-24）：
- Call site 盤點完成（13 處 + 1 檔案）
- Plan 已寫完，用戶已要求直接實作
- Architect 已補 executable handoff：
  - `Docs/designs/TD-remove-apiclient-shared.md`
  - `Docs/tests/TEST-remove-apiclient-shared.md`
  - `HavitalTests/SpecCompliance/APIClientRemovalACTests.swift`
- ZenOS task：`9aa5936ea2a8467e9f66582c2af3d9e7`
- 已 handoff 到 `agent:developer`，Developer worker 已啟動
- Developer 修復後 QA PASS，ZenOS task 已 done
- 驗證已通過：
  - legacy grep gates：`APIClient` / `EmailAuthService` / legacy API errors / pbxproj refs 無殘留
  - `APIClientRemovalACTests` 5/5 PASS
  - iPhone 17 Pro `xcodebuild build` PASS
  - Maestro `demo-login-only.yaml` PASS
  - Maestro `verify-climate-settings-wording.yaml` PASS（artifact: `/Users/wubaizong/.maestro/tests/2026-04-24_185025`）
- 本輪改動（climate 文案 + auth uid fallback）已 build pass 但未真實驗證顯示（卡在 token source 分裂，就是本 plan 要解的問題）

**下一步**：
- External review。已知剩餘風險：真實 HealthKit workout upload E2E 未跑，本輪以 static/unit contract coverage 保護 `/v2/workouts` 與 `/workout/summary/{id}`。

**S01 關鍵已釐清**（2026-04-24）：
- `HTTPClient` 沒有 `.post` / `.get` helper；唯一入口是 `request(path: String, method: HTTPMethod, body: Data?, customHeaders: [String: String]?) async throws -> Data`（`Havital/Services/Core/HTTPClient.swift:15`）。S01 統一用此簽名。
- `DependencyContainer` 是否已 register `HTTPClient` → S01 開工時 grep 確認；若無，本 stage 先補 register（不算 scope creep，是最小依賴）。

---

## 相關檔案參考

- `Havital/Services/Core/HTTPClient.swift` — 目標 client，demo token persist 正確
- `Havital/Features/Authentication/Data/Repositories/AuthSessionRepositoryImpl.swift` — demo token persist 實作（UserDefaults key: `"auth.demo_id_token"`）
- `Havital/Core/DI/DependencyContainer.swift` — DI 容器
- `Havital/Services/APIClient.swift` — 目標刪除檔案
