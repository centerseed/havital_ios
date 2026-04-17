---
type: SPEC
id: HANDOFF-2026-04-17-02-phase-a
status: Approved
l2_entity: training-plan-versioning
created: 2026-04-17
updated: 2026-04-17
parent: PROD-2026-04-17-02-v2-hardening
---

# Phase A Developer Handoff — V2 硬化止血

> 對應上層 plan：`docs/05-sprints/production-incidents/2026-04-17-02-v1v2-routing-fix-plan.md`
> 本 handoff 覆蓋 Phase A 全部 6 個 Task（A-0b / A-1 / A-2 / A-3 / A-4 / A-5）。每個 Task 為獨立 executable，Developer 可依「依賴順序」章節分波啟動。
> 所有檔案路徑為**絕對路徑**。

---

## 0. 前置確認（Architect 偵察結果，2026-04-17）

此段為 Developer 的 ground truth，**不要再查**。

### 0.1 TrainingVersionRouter 介面（`Havital/Core/Infrastructure/TrainingVersionRouter.swift`）

```swift
final class TrainingVersionRouter {
    init(userProfileRepository: UserProfileRepository)
    func getTrainingVersion() async -> String  // "v1" | "v2"，錯誤時回 "v1"
    func isV2User() async -> Bool              // async，非同步
    func isV1User() async -> Bool
}
```

- **async**（非 sync）。所有呼叫點必須在 async context。
- 已註冊在 DI：`DependencyContainer.registerTrainingVersionRouter()`。
- **容錯行為**：取不到 user profile → 預設 v1（向下相容）。V2 用戶若 cold start race 可能回 v1；見 A-4 的 race 風險。

### 0.2 TrainingPlanV2Repository DI

- Protocol：`Havital/Features/TrainingPlanV2/Domain/Repositories/TrainingPlanV2Repository.swift`（318 行）
- 註冊點：`Havital/Features/TrainingPlanV2/Data/Repositories/TrainingPlanV2RepositoryImpl.swift:558`
  ```swift
  register(repository as TrainingPlanV2Repository, forProtocol: TrainingPlanV2Repository.self)
  ```
- **OnboardingFeatureViewModel 已經有注入**：
  - `:25-26` 宣告 property
  - `:209-216` init 參數
  - `:228-229` 和 `:1140-1141` convenience init 從 container resolve
  - 代表 V2 Repo 立即可用，**不需要額外 wiring**
- 方法對應：
  - V1 `trainingPlanRepository.getOverview()` → V2 `trainingPlanV2Repository.getOverview() async throws -> PlanOverviewV2`
  - V1 `trainingPlanRepository.createWeeklyPlan(week, startFromStage, isBeginner)` → V2 建立週課表入口見下方 A-2

### 0.3 OnboardingFeatureViewModel 真實行號確認

- **檔案**：`Havital/Features/Onboarding/Presentation/ViewModels/OnboardingFeatureViewModel.swift`（共 1145 行）
- `loadTrainingOverview()` 在 **line 730-743**（plan 寫 735 是 call V1 的那行，正確）
- `completeOnboarding(startFromStage:)` 在 **line 761-780**（plan 寫 766 是 call V1 的那行，正確）

### 0.4 WeeklyPlanViewModel 真實 surface 確認

- **檔案**：`Havital/Features/TrainingPlan/Presentation/ViewModels/WeeklyPlanViewModel.swift`（共 323 行）
- **Plan 裡寫的 line 289 實際對應 `loadOverview()` 方法，呼叫 V1 `repository.getOverview()`**（正確）
- Plan 裡寫的 `:136/185/242/265` weekly/createWeekly/modify/refresh 方法名修正：
  - `:136` `loadWeeklyPlan()` → `repository.getWeeklyPlan(planId:)`
  - `:185` `refreshWeeklyPlan(silent:)` → `repository.refreshWeeklyPlan(planId:)`
  - `:242` `generateWeeklyPlan(...)` → `repository.createWeeklyPlan(week:, startFromStage:, isBeginner:)`
  - `:265` `modifyWeeklyPlan(_:)` → `repository.modifyWeeklyPlan(planId:, updatedPlan:)`
  - `:289` `loadOverview()` → `repository.getOverview()`
- **共 5 個入口**，A-3 必須全部覆蓋（plan 原只列 4 個，實際 5 個）。

### 0.5 APIClient decode failure 統一點

- **檔案**：`Havital/Services/APIClient.swift`
- 所有 decode 失敗統一在 `:127 Logger.firebase("APIClient decode failed", ...)` 記錄
- **含完整 `response_preview` 前 1000 字元 + `path` + `expected_type`**
- A-0a 撈 prod decode failure 的 source = Cloud Logging query `operation="decode_failure"`

### 0.6 DomainError 現有 case

- **檔案**：`Havital/Shared/Errors/DomainError.swift`
- 沒有 `wrongVersionForPath` / `wrongVersionForEndpoint` / `incorrectVersionRouting` case
- **本 handoff 統一新增 `.incorrectVersionRouting(context: String)`** — 見 A-3 / A-4 具體位置
- 新 case 必須：
  - 加到 `shouldShowErrorView` switch（A-3 情境要顯示 `true`）
  - 加到 `isRetryable` switch（回 `false`，重試無用）
  - 加到 `errorDescription`：「版本不一致，請重新啟動 app（v2_user_entered_v1_path）」

### 0.7 Logger.firebase API 形狀

```swift
Logger.firebase(
    "human readable message",              // @autoclosure
    level: .error,                          // .debug | .info | .warn | .error
    labels: [
        "cloud_logging": "true",            // 強制上傳
        "module": "...",
        "operation": "..."                  // alert/query key
    ],
    jsonPayload: [String: Any]?
)
```

- **`labels["cloud_logging"] = "true"` 必填**（否則 info 級不會上傳）
- Alert 的 query key 放 `labels["operation"]`（對齊 Cloud Monitoring filter）

### 0.8 A-3 根因已定位

- `Havital/Views/ContentView.swift:289-301` 的 `trainingPlanTab()` 已有 V1/V2 分流（正確）
- `ContentView:13` `@State private var trainingVersion: String = "v1"` **預設 v1**
- `checkTrainingVersion()` 是 async Task → **cold start race**：`trainingVersion` 在初始 render 可能仍是 "v1"，此時已創建 V1 `TrainingPlanView()` → 進而創建 `WeeklyPlanViewModel(repository: V1Repo)`（見 `TrainingPlanViewModel.swift:386`）
- `ContentView` 本有 `isCheckingVersion` 防護（`:290-293`），但 `isCheckingVersion` 初始值 / 生命週期需確認（在 A-3 Stage 2 處理）
- 次要入口：`Havital/Views/Training/TrainingProgressView.swift:408` 有類似 V1 TrainingPlanView 邏輯引用
- **結論**：A-3 Stage 1 仍用 early-return + log 止血（防禦所有入口）；A-3 本 handoff **新增一項子任務 A-3b**，補 `isCheckingVersion` gate 與 cold start race 驗證，不延後到 C-1

---

## 1. 依賴順序與並行建議

```
Wave 1（可立即全部並行）：
  ├─ A-0b：Debug Export Panel（DEBUG-only，不影響 production code path）
  ├─ A-1：OnboardingFeatureVM.loadTrainingOverview 分流
  ├─ A-2：OnboardingFeatureVM.completeOnboarding 分流
  ├─ A-4：V1 Repo Guard decorator
  └─ A-5：V1 @deprecated doc comment

Wave 2（依賴 Wave 1 的 DomainError 新增）：
  └─ A-3：WeeklyPlanViewModel 5 個入口 early-return + A-3b cold start race 驗證

依賴關係：
- A-3 依賴 A-4 先定義好 DomainError.incorrectVersionRouting（或 A-3 自己先加）
  → 建議主 Claude 同波派 A-4，讓 A-4 先把 case 加進 DomainError.swift，A-3 跟著用
- A-1 / A-2 互不依賴
- A-0b 完全獨立（#if DEBUG）
- A-5 純文件註解，不動行為
```

**派工建議**：Wave 1 一次派 5 個 developer subagent 平行跑；A-3 等 Wave 1 完成 merge 後派。

---

## 2. Task A-0b — Debug Export Panel

### 2.1 Scope

**Why**：Plan A-0 需要 prod_live V2 endpoint response 做 contract fixture，但用戶不想手動 curl。改為在 app 內加 DEBUG-only panel，讓開發/QA 在 simulator 直接觸發 V2 endpoint 並匯出 raw JSON 到 Share Sheet，Developer 再存進 repo fixture。

**What**：在 `UserProfileView` 的 `debugSection`（`:668-680`）下，新增一個 NavigationLink 「V2 Fixture Export」，進入後提供 3 個按鈕對應 3 種 target_type（race_run / beginner / maintenance），點擊後：
1. 呼叫對應 V2 endpoint（`/v2/plan/overview`、`/v2/plan/weekly/{planId}`、`/v2/plan/status`）
2. 攔截 raw response body（不經過 DTO decode）
3. 寫入 `FileManager.default.temporaryDirectory` 為 `.json` 檔
4. 彈出 Share Sheet 讓用戶存出

### 2.2 Done Criteria（AC）

- [ ] **AC-A0B-01**：新增檔案 `Havital/Features/Debug/V2FixtureExportView.swift`，以 `#if DEBUG` 完整包裹
- [ ] **AC-A0B-02**：`UserProfileView.debugDetailView` 新增入口 NavigationLink「V2 Fixture Export」（`#if DEBUG` 內）
- [ ] **AC-A0B-03**：Panel 提供 3 個 action：
  - `Export race_run overview + weekly`
  - `Export beginner overview + weekly`
  - `Export maintenance overview + weekly`
  - 每個 action **只對當前登入用戶的資料**操作（不切換帳號）；按鈕 disabled 若 `trainingVersion != "v2"`，並顯示提示「請先切到 V2 demo user」
- [ ] **AC-A0B-04**：攔截方式——**不要**侵入 `APIClient.request<T>`。改用 `URLSession` 直接打（bypass decode），呼叫 `APIClient.makeRequest(path:method:body:)`（現有 internal API，見 `APIClient.swift:60-63`）拿到 URLRequest，然後自己 `URLSession.shared.data(for:)` 取 `(Data, URLResponse)`
- [ ] **AC-A0B-05**：匯出檔名格式 `v2_{target_type}_{endpoint}_{yyyyMMdd-HHmmss}.json`，包含 header comment JSON 附加 meta：
  ```json
  {
    "_meta": {
      "captured_at": "2026-04-17T10:30:00Z",
      "app_version": "1.2.3",
      "build_number": "456",
      "endpoint": "/v2/plan/overview",
      "uid_hash": "sha256-first-8-chars"
    },
    "response": { /* raw body */ }
  }
  ```
- [ ] **AC-A0B-06**：PII 清理——`uid_hash` 為 SHA256 前 8 字元；不寫出 Authorization token；不寫出 email / phone（由 Developer 逐欄位 review V2 response body，若有就替換成 `[REDACTED]`）
- [ ] **AC-A0B-07**：Share Sheet 透過 `UIActivityViewController` 呈現；使用者可選擇 AirDrop / Messages / Save to Files
- [ ] **AC-A0B-08**：Panel 開啟畫面上顯示當前 `trainingVersion`（呼叫 `TrainingVersionRouter.getTrainingVersion()`）與目前登入 uid hash（debug 方便）
- [ ] **AC-A0B-09**：Release build **零影響**——`#if DEBUG` 外不留任何 code（包含 import）

### 2.3 影響檔案

| 檔案 | 動作 |
|---|---|
| `Havital/Features/Debug/V2FixtureExportView.swift` | 新增 |
| `Havital/Views/UserProfileView.swift` | 修改（debugDetailView 加入口） |

### 2.4 測試要求

- **手動**（DEBUG build）：
  - 在 simulator 以 V2 demo user 登入，進 Settings → Developer Tools → V2 Fixture Export
  - 點「race_run overview + weekly」，彈 Share Sheet，存到 Files
  - 打開存檔，確認 JSON 有 `_meta` + `response`，raw body 無 PII
- **Unit test（新增）**：`HavitalTests/Features/Debug/V2FixtureExportTests.swift`（#if DEBUG 包）
  - 測 `redactPII(_ json: Any) -> Any` helper：餵含 email 的 mock dict → 回傳應替換
  - 測 `buildMetaEnvelope(endpoint:, rawData:)` → 驗證 meta 欄位齊全 + uid_hash 長度 = 8

### 2.5 驗收證據（給 QA）

- 截圖 1：Developer Tools 列表顯示「V2 Fixture Export」
- 截圖 2：Panel 畫面，當 trainingVersion = v1 時按鈕 disabled + 提示
- 截圖 3：V2 user 切入後按鈕 enabled + Share Sheet 彈出
- 附一份成功匯出的 JSON 檔（PII 已清理，可 commit 進 `HavitalTests/TrainingPlan/Unit/APISchema/Fixtures/PlanOverview/prod_live_race_run.json`）
- 證明 Release build 無此 panel：跑一次 Release build 的 `UserProfileView` screenshot

---

## 3. Task A-1 — OnboardingFeatureVM.loadTrainingOverview V2 分流

### 3.1 Scope

**Why**：V2 用戶 onboarding 結束後呼叫 `trainingPlanRepository.getOverview()` 打到 `/plan/race_run/overview`，拿到 shape 不符被 V1 DTO decode 炸掉。12% V2 用戶踩到。

**What**：`OnboardingFeatureViewModel.loadTrainingOverview()` 用 `TrainingVersionRouter.isV2User()` 分流；V2 走 V2 Repo。

### 3.2 Done Criteria（AC）

- [ ] **AC-A1-01**：`OnboardingFeatureViewModel` 新增 `private let versionRouter: TrainingVersionRouter` property + init 參數 + convenience init 從 container resolve
- [ ] **AC-A1-02**：`loadTrainingOverview()` 改寫為：
  ```swift
  if await versionRouter.isV2User() {
      let overviewV2 = try await trainingPlanV2Repository.getOverview()
      self.trainingOverviewV2 = overviewV2  // 新 property
      Logger.firebase("onboarding_load_overview_v2", level: .info,
                      labels: ["cloud_logging": "true", "module": "OnboardingVM", "operation": "load_overview_v2"],
                      jsonPayload: ["uid": AuthenticationService.shared.user?.uid ?? ""])
  } else {
      let overview = try await trainingPlanRepository.getOverview()
      self.trainingOverview = overview
  }
  ```
- [ ] **AC-A1-03**：新增 `@Published var trainingOverviewV2: PlanOverviewV2?`；**不要**把 V2 結果硬塞進 `trainingOverview`（V1 型別）
- [ ] **AC-A1-04**：後續 `loadTargetPace()` 與依賴 `trainingOverview` 的 call site 需補 V2 分支（至少讓 `loadTargetPace()` 在 V2 時從 `trainingOverviewV2.mainRaceId` 抽，取不到就回 `"6:00"` 預設 fallback）
- [ ] **AC-A1-05**：API call tracking：V2 路徑呼叫前加 `.tracked(from: "OnboardingFeatureVM: loadTrainingOverviewV2")`；V1 路徑為 `"OnboardingFeatureVM: loadTrainingOverviewV1"`
- [ ] **AC-A1-06**：錯誤處理：V2 Repo throw 時，`self.error` 設為 `DomainError` 轉換後的 userFriendlyMessage（非 `error.localizedDescription`）
- [ ] **AC-A1-07**：`trainingVersion == nil` → 走 V1（`isV2User()` 回 false，符合預期）
- [ ] **AC-A1-08**：Unit test 新增（見 3.4）

### 3.3 影響檔案

| 檔案 | 動作 |
|---|---|
| `Havital/Features/Onboarding/Presentation/ViewModels/OnboardingFeatureViewModel.swift` | 修改（:25-26 新增 router property，:209-229 init 改、:730-743 改寫、:1140-1141 convenience） |
| `HavitalTests/Features/Onboarding/Presentation/ViewModels/OnboardingFeatureViewModelTests.swift` | 修改（加 4 case） |

### 3.4 測試要求

- **Unit test 4 case**（mock `TrainingVersionRouter` + URLProtocol 攔 HTTP）：
  - `test_loadTrainingOverview_v2User_callsV2Repo_notV1`：mock `isV2User()` 回 true，呼叫 method，URLProtocol 驗證**只收到** `/v2/plan/overview` 一次，沒有 `/plan/race_run/overview`
  - `test_loadTrainingOverview_v1User_callsV1Repo_notV2`：反之
  - `test_loadTrainingOverview_v2Repo_throws_errorMessageSet`：V2 repo 丟 `TrainingPlanV2Error.overviewNotFound` → `self.error` 非 nil 且為中文 userFriendly 文字
  - `test_loadTrainingOverview_nilVersion_fallbackToV1`：mock router 回 v1（`trainingVersion = nil` 情境）→ 走 V1 path
- **Mock 策略**：用 protocol mock `TrainingVersionRouter`（需把它改成 protocol，或用 class override with `@testable import`）
- **URLProtocol**：復用既有 test infra（`HavitalTests/` 應已有 URLProtocolStub，若無 Developer 在本 task 內新增 minimal stub）

### 3.5 驗收證據

- 4 個 unit test 全 pass 的 xcodebuild output
- `xcodebuild clean build ...` 零 error
- 手動 simulator 驗證：V2 demo user 跑完 onboarding，Network log（或 DEBUG print）顯示只打 `/v2/plan/overview`

---

## 4. Task A-2 — OnboardingFeatureVM.completeOnboarding V2 分流

### 4.1 Scope

**Why**：V2 用戶完成 onboarding 時 `trainingPlanRepository.createWeeklyPlan(...)` 打 V1 endpoint，失敗或錯入 V1 資料庫。

**What**：同 A-1 pattern，V2 用戶呼叫 `trainingPlanV2Repository.generateWeeklyPlan(...)`（見下方參數轉換）。

### 4.2 Done Criteria（AC）

- [ ] **AC-A2-01**：`completeOnboarding(startFromStage:)` 改寫為：
  ```swift
  if await versionRouter.isV2User() {
      _ = try await trainingPlanV2Repository.generateWeeklyPlan(
          weekOfTraining: 1,                  // V2 onboarding 完成 = 第 1 週
          forceGenerate: false,
          promptVersion: "v2",
          methodology: "paceriz"              // 若 isBeginner 則改為相應 methodology
      )
      Logger.firebase("onboarding_complete_v2", level: .info,
                      labels: ["cloud_logging": "true", "module": "OnboardingVM", "operation": "complete_onboarding_v2"],
                      jsonPayload: ["uid": AuthenticationService.shared.user?.uid ?? ""])
  } else {
      _ = try await trainingPlanRepository.createWeeklyPlan(...)  // 現行
  }
  ```
- [ ] **AC-A2-02**：參數對應決策——`isBeginner == true` 時 V2 `methodology` 設為 `"beginner"`；否則 `"paceriz"`（本 handoff 預設值，後續可由 Architect review 調整）
- [ ] **AC-A2-03**：API call tracking：`.tracked(from: "OnboardingFeatureVM: completeOnboardingV2")` / `"...V1"`
- [ ] **AC-A2-04**：V1 用戶行為 byte-for-byte 不變（既有參數、既有 log、既有 error handling）
- [ ] **AC-A2-05**：錯誤 fallback：V2 generateWeeklyPlan 失敗 → `self.error` 用 userFriendlyMessage；return false（現行行為保留）
- [ ] **AC-A2-06**：Unit test 4 case（對稱 A-1）

### 4.3 影響檔案

| 檔案 | 動作 |
|---|---|
| `OnboardingFeatureViewModel.swift` | 修改 `:761-780` |
| `OnboardingFeatureViewModelTests.swift` | 修改 |

### 4.4 測試要求

- Unit test 4 case：
  - `test_completeOnboarding_v2User_callsV2generateWeekly_notV1`
  - `test_completeOnboarding_v1User_callsV1createWeeklyPlan_notV2`
  - `test_completeOnboarding_v2_beginnerFlag_mapsMethodologyBeginner`
  - `test_completeOnboarding_v2_nonBeginner_mapsMethodologyPaceriz`
- **URLProtocol 斷言**：V2 test case 期望 `/v2/plan/weekly`（或依 V2 DataSource 實際 path，Developer 從 `TrainingPlanV2RemoteDataSource.swift` 確認）被打一次，`/plan/race_run/*` 0 次

### 4.5 驗收證據

- Maestro `onboarding-race-paceriz.yaml` （V1 flow）仍 pass（regression）
- 4 個 unit test 全 pass
- V2 Maestro flow（B-2 產出）可觸發此路徑並 pass

---

## 5. Task A-3 — WeeklyPlanViewModel 5 入口 Early-Return + Cold Start Race 修正

### 5.1 Scope

**Why**：V2 用戶因 cold start race（`ContentView.trainingVersion` 初始 `"v1"`）會先進 V1 `TrainingPlanView`，建出 V1 `WeeklyPlanViewModel`，然後對 5 個入口打 `/plan/race_run/*`。

**What**：
- **A-3a（Stage 1 止血）**：在 5 個入口 early-return 並 log；UI 進 error state
- **A-3b（根因修）**：修 `ContentView.checkTrainingVersion()` race — `isCheckingVersion` 預設 `true`，結束才切 false，保證 `TrainingPlanView()` 不會被 race-render

### 5.2 Done Criteria（AC）

- [ ] **AC-A3-01**：`DomainError.swift` 新增 case `case incorrectVersionRouting(context: String)`
  - `errorDescription`：`"版本不一致，請重新啟動 App（\(context)）"`
  - `shouldShowErrorView = true`
  - `isRetryable = false`
  - `userFriendlyMessage`：`"您的帳號為 V2，但載入了舊版畫面。請重新啟動 App 後再試。"`
- [ ] **AC-A3-02**：`WeeklyPlanViewModel` 新增 `private let versionRouter: TrainingVersionRouter`；convenience init 從 container resolve
- [ ] **AC-A3-03**：以下 **5 個方法**入口統一加 guard（不是 4 個）：
  - `loadWeeklyPlan()` `:118`
  - `refreshWeeklyPlan(silent:)` `:175`
  - `generateWeeklyPlan(...)` `:231`
  - `modifyWeeklyPlan(_:)` `:261`
  - `loadOverview()` `:281`

  Pattern：
  ```swift
  if await versionRouter.isV2User() {
      Logger.firebase("v2_user_entered_v1_viewmodel",
                      level: .error,
                      labels: [
                        "cloud_logging": "true",
                        "module": "WeeklyPlanVM",
                        "operation": "v2_user_entered_v1_viewmodel"
                      ],
                      jsonPayload: [
                        "method": "loadWeeklyPlan",
                        "uid": AuthenticationService.shared.user?.uid ?? ""
                      ])
      state = .error(.incorrectVersionRouting(context: "WeeklyPlanVM.loadWeeklyPlan"))
      return
  }
  ```
  `loadOverview` 入口把 `overviewState = .error(...)` 而非 `state`。
- [ ] **AC-A3-04**：每個入口的 log `jsonPayload["method"]` 必須不同（用方法名）
- [ ] **AC-A3-05**：**A-3b cold start race 修復** — `ContentView.swift`：
  - `:13` `@State private var trainingVersion: String = "v1"` 改為 `Optional`：`@State private var trainingVersion: String? = nil`
  - `isCheckingVersion` 初始保持 true；`trainingPlanTab()` 的 switch 改為：
    ```swift
    if isCheckingVersion || trainingVersion == nil {
        ProgressView()
    } else if trainingVersion == "v2" {
        TrainingPlanV2View()
    } else {
        TrainingPlanView()
    }
    ```
  - 效果：V2 user cold start 期間看 loading，而非先 mount V1 View
- [ ] **AC-A3-06**：`TrainingProgressView.swift:408` 檢查是否直接 build V1 TrainingPlanView — 若是，加同樣 isCheckingVersion guard 或路由至 V2 View（若無此路徑 build V1 View，記錄在 Completion Report 並略過）
- [ ] **AC-A3-07**：UI error 顯示 — `ErrorView` 讀 `DomainError.userFriendlyMessage`，本 AC 不改 ErrorView，只確認既有 ErrorView 能正確顯示新 case 文字（Developer 手動驗證）
- [ ] **AC-A3-08**：V1 用戶行為完全不變（`isV2User()` 回 false → 跳過 guard）
- [ ] **AC-A3-09**：Unit test 新增
- [ ] **AC-A3-10**：log 事件 key `v2_user_entered_v1_viewmodel` 可在 Cloud Logging 用 `labels.operation="v2_user_entered_v1_viewmodel"` query 到（對應 B-3 Alert #1）

### 5.3 影響檔案

| 檔案 | 動作 |
|---|---|
| `Havital/Shared/Errors/DomainError.swift` | 修改（加 case + 3 個 switch） |
| `Havital/Features/TrainingPlan/Presentation/ViewModels/WeeklyPlanViewModel.swift` | 修改（5 入口 + init + property） |
| `Havital/Views/ContentView.swift` | 修改（:13, :290-301） |
| `Havital/Views/Training/TrainingProgressView.swift` | 視 AC-A3-06 查核結果決定 |
| `HavitalTests/TrainingPlan/Unit/ViewModel/WeeklyPlanViewModelTests.swift` | 修改 |
| `HavitalTests/Shared/Errors/DomainErrorMappingTests.swift` | 修改（新 case 覆蓋） |

### 5.4 測試要求

- **Unit test**：
  - `test_5methods_v2User_earlyReturn_noHTTP`：5 個方法各一個 test case，mock V2 user → URLProtocol 斷言 **0 次** `/plan/race_run/*` HTTP
  - `test_5methods_v1User_normalFlow`：V1 user → 正常發 HTTP
  - `test_DomainError_incorrectVersionRouting_shouldShowErrorView_true`
  - `test_DomainError_incorrectVersionRouting_userFriendlyMessage_localized`
- **Integration smoke**（手動）：`ContentView` cold start，V2 demo user 登入 → 首屏短暫 ProgressView → 直接看到 V2 View（不閃 V1 ErrorView）

### 5.5 驗收證據

- Cold start 錄影（DEBUG build）：V2 user 啟動 app → 0.5-2 秒內 ProgressView → V2 TrainingPlanV2View，**全程不出現 V1 ErrorView**
- Cloud Logging 測試：在 DEBUG build 手動讓 V2 user 呼叫 `WeeklyPlanViewModel.loadWeeklyPlan()`（例如透過 debug panel），驗證 Firestore `logs` collection 出現 `operation="v2_user_entered_v1_viewmodel"` 記錄
- 6+ 個新 unit test 全 pass

---

## 6. Task A-4 — V1 Repository Guard Decorator

### 6.1 Scope

**Why**：深度防禦 — 即使 A-1/A-2/A-3 有遺漏，V1 Repo 被呼叫時最後一道防線能攔住 V2 user。符合 CLAUDE.md「Repository 被動」原則 → **用 decorator，不是改 Repo 本身**。

**What**：新增 `V1RepoGuardDecorator`，包住 `TrainingPlanRepository` protocol，注入前判斷 V2 user 則直接 throw。

### 6.2 Done Criteria（AC）

- [ ] **AC-A4-01**：新增檔案 `Havital/Features/TrainingPlan/Data/Safeguards/V1RepositoryGuardDecorator.swift`
- [ ] **AC-A4-02**：實作 `final class V1RepositoryGuardDecorator: TrainingPlanRepository`，constructor inject `wrapped: TrainingPlanRepository` + `versionRouter: TrainingVersionRouter`
- [ ] **AC-A4-03**：覆寫 **所有** `TrainingPlanRepository` protocol 方法，每個方法 pattern：
  ```swift
  func getOverview() async throws -> TrainingPlanOverview {
      try await guardV1Access(method: "getOverview")
      return try await wrapped.getOverview()
  }

  private func guardV1Access(method: String) async throws {
      if await versionRouter.isV2User() {
          Logger.firebase(
              "v1_endpoint_blocked_for_v2_user",
              level: .error,
              labels: [
                "cloud_logging": "true",
                "module": "V1Guard",
                "operation": "v1_endpoint_blocked_for_v2_user"
              ],
              jsonPayload: [
                "method": method,
                "uid": AuthenticationService.shared.user?.uid ?? ""
              ]
          )
          throw DomainError.incorrectVersionRouting(context: "V1Guard.\(method)")
      }
  }
  ```
- [ ] **AC-A4-04**：修改 DI wiring — 找到 `TrainingPlanRepository` 註冊點（grep `register.*TrainingPlanRepository`），把 `TrainingPlanRepositoryImpl` 包一層：
  ```swift
  let impl = TrainingPlanRepositoryImpl(...)
  let guarded = V1RepositoryGuardDecorator(wrapped: impl, versionRouter: resolve())
  register(guarded as TrainingPlanRepository, ...)
  ```
- [ ] **AC-A4-05**：不違反「Repository 被動」原則 — Guard 是 decorator，**不改** `TrainingPlanRepositoryImpl`
- [ ] **AC-A4-06**：Cold start race 風險（風險章節 4 提到）— Decorator 呼叫 `isV2User()`，若 user profile 尚未 bootstrap（race）會 default v1 → 不攔，正常放行。**這是可接受的**（只有 cold start 初期 race window 內會放過 V2 user，bootstrap 完成後即正確）。但 Unit test 須覆蓋此情境（見 6.4）
- [ ] **AC-A4-07**：V1 用戶行為不變 — `isV2User()` 回 false → decorator 直通
- [ ] **AC-A4-08**：log key `v1_endpoint_blocked_for_v2_user` 對應 B-3 Alert #1

### 6.3 影響檔案

| 檔案 | 動作 |
|---|---|
| `Havital/Features/TrainingPlan/Data/Safeguards/V1RepositoryGuardDecorator.swift` | 新增 |
| `Havital/Shared/Errors/DomainError.swift` | 修改（若 A-3 尚未加 case，A-4 加） |
| DI 註冊檔（Developer grep 定位，通常在 `TrainingPlanRepositoryImpl.swift` extension 或 `AppDependencyBootstrap.swift`） | 修改（包 decorator） |
| `HavitalTests/TrainingPlan/Unit/Safeguards/V1RepositoryGuardDecoratorTests.swift` | 新增 |

### 6.4 測試要求

- Unit test（新增檔案）：
  - `test_v2User_getOverview_throwsIncorrectVersionRouting_noHTTP`
  - `test_v1User_getOverview_passesThrough`
  - `test_v2User_createWeeklyPlan_throws`
  - `test_coldStartRace_unknownVersion_defaultsV1_passesThrough`（mock router 回 v1 → 應放行，記錄在 Completion Report）
  - `test_logFiredWithCorrectOperation`：用 Logger spy 驗證 `labels.operation = "v1_endpoint_blocked_for_v2_user"`
- Mock 策略：Mock `TrainingPlanRepository` protocol（spy mode 記錄呼叫）+ mock router

### 6.5 驗收證據

- 5+ unit test 全 pass
- DI wiring 驗證：Developer 在 DEBUG 印 `type(of: container.resolve() as TrainingPlanRepository)` 結果應為 `V1RepositoryGuardDecorator`
- 確認 decorator 包住 **所有** protocol method（不能漏一個；Developer 逐個對照 protocol 簽名 checklist）

---

## 7. Task A-5 — V1 @deprecated Doc Comment + Policy Doc

### 7.1 Scope

**Why**：戰略決定 V1 被動維護，Code 需有明確標記避免新功能誤用；但決策 3 = 折衷，**只加 doc comment，不啟用 compile warning**。

**What**：加 `/// @deprecated ...` doc comment + 新增 policy 文件 `docs/architecture/v1-deprecation-policy.md`。

### 7.2 Done Criteria（AC）

- [ ] **AC-A5-01**：以下 4 處檔案頂端（type 宣告上方）加 doc comment：
  ```
  /// @deprecated V1 被動維護，新功能請走 V2（TrainingPlanV2Repository）。預計 2026-07-17 後升級為 compile warning。
  /// 詳見：docs/architecture/v1-deprecation-policy.md
  ```
  - `Havital/Features/TrainingPlan/Domain/Repositories/TrainingPlanRepository.swift`（protocol）
  - `Havital/Features/TrainingPlan/Data/Repositories/TrainingPlanRepositoryImpl.swift`（class）
  - `Havital/Features/TrainingPlan/Presentation/ViewModels/WeeklyPlanViewModel.swift`
  - `Havital/Views/Training/TrainingPlanView.swift`
- [ ] **AC-A5-02**：**不啟用** `@available(*, deprecated, message: ...)` — 避免產生 30+ warning
- [ ] **AC-A5-03**：新增檔案 `docs/architecture/v1-deprecation-policy.md`，內容：
  - Frontmatter（type: REF, id: REF-v1-deprecation-policy, status: Approved, l2_entity: training-plan-versioning）
  - § 戰略決定（V1 被動維護）
  - § Bug Triage 規則（崩潰性修、其他進 `docs/05-sprints/v1-known-issues.md`）
  - § 遷移時機（Phase 1 doc comment / Phase 2 2026-07-17 升級 compile warning / Phase 3 移除）
  - § 不在 app 內放升級 UI、不推 V1 用戶
- [ ] **AC-A5-04**：`.claude/rules/architecture.md` 底部加一行：
  `> V1 訓練計劃模組為被動維護，詳見 docs/architecture/v1-deprecation-policy.md`
- [ ] **AC-A5-05**：`.claude/rules/debugging.md` Failure Classification 表格新增欄位（或底下加 note）區分 V1/V2 triage 行為（Architect 可後續補，本 task 先加最小 note：「V1 bug 除 crash/登入失敗外 → log only；V2 bug 一律修 + P0」）
- [ ] **AC-A5-06**：建 follow-up task 在 ZenOS（或 `docs/05-sprints/followups.md` 若 ZenOS 尚未為此開 task）：「2026-07-17 review V1 call site 數量，決定是否升 compile warning」

### 7.3 影響檔案

| 檔案 | 動作 |
|---|---|
| `TrainingPlanRepository.swift` | 修改（頂端 comment） |
| `TrainingPlanRepositoryImpl.swift` | 修改 |
| `WeeklyPlanViewModel.swift` | 修改 |
| `TrainingPlanView.swift` | 修改 |
| `docs/architecture/v1-deprecation-policy.md` | 新增 |
| `.claude/rules/architecture.md` | 修改 |
| `.claude/rules/debugging.md` | 修改 |

### 7.4 測試要求

- 無 code 行為變更 → **無 unit test**
- `xcodebuild clean build ...` 通過且 **無新 warning**
- 文件 frontmatter 正確（type/id/status/l2_entity 四欄齊全）

### 7.5 驗收證據

- 4 處檔案 diff 僅含 doc comment
- Policy 文件 URL
- Build output 無 new warning

---

## 8. 共通要求（所有 Task 都適用）

1. **遵守 CLAUDE.md**：
   - ViewModel @MainActor ✓（既有）
   - 依賴 Protocol 不依賴 Impl ✓
   - TaskManageable 既有實作不動（A-3 etc 不新增 Task，用 existing structure）
   - `.tracked(from: ...)` 所有新 API call 都要掛
2. **測試前提**：每個 Task Developer 必須在 simulator iPhone 17 Pro 實機跑過至少一次
3. **`/simplify` 是交付的一部分**：每個 Task 完成後、QA 前執行
4. **Completion Report 格式**：按 Developer SKILL.md 規範，列出每條 AC 的 evidence（file:line + test name + screenshot）
5. **不得**：
   - 跳過 `/simplify`
   - 說「看起來應該可以」而沒跑 test
   - 寫入觸及 Production 的 debug code（僅 A-0b 在 `#if DEBUG` 內）
   - 對 V1 Repo 的 decorator 以外做任何修改（A-4）

---

## 9. QA 驗收對照（給後續 QA skill 參考）

- A-0b：手動 panel 操作 + fixture 檔案可存進 repo
- A-1 / A-2：URLProtocol unit test + Maestro V2 onboarding flow（待 B-2 產出，暫手動）+ V1 Maestro regression
- A-3：cold start 錄影 + 5 入口 URLProtocol test
- A-4：Guard unit test + DI 驗證
- A-5：文件 diff + build 無 warning

每個 Task 交付時 QA 獨立派一次，驗收失敗則 developer 重新 open。

---

## 10. 部署門檻（所有 A-* 全綠才進 B）

- [ ] 6 個 Task 全部 QA PASS
- [ ] `xcodebuild clean build ... iPhone 17 Pro` 零 error
- [ ] V1 regression Maestro flow pass（`onboarding-race-paceriz.yaml`、`regression-i18n-english.yaml` 等抽樣 3 條）
- [ ] `/simplify` 執行並附紀錄
- [ ] Architect 雙階段審查（Spec Compliance + Code Quality）PASS

Phase A 止血完成後才進 Phase B 硬化基建。
