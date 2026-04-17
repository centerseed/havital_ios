---
type: SPEC
id: PROD-2026-04-17-02-v2-hardening
status: Under Review
l2_entity: training-plan-versioning
created: 2026-04-17
updated: 2026-04-17
supersedes: PROD-2026-04-17-02-v1v2-routing-fix
---

# V2 品質硬化 Plan（V1 被動維護）

> 本版覆蓋前版 `V1/V2 Routing Fix Plan`。策略從「修 routing bug」轉為 **「V2 零容忍硬化 + V1 被動凍結」**。前版 Task 拆解被本版吸收並擴大範圍。

---

## 戰略前提

1. **V2 是主體**
   - 所有新用戶 onboarding 後 `trainingVersion = "v2"`
   - 產品、工程、QA 投資全部指向 V2
2. **V1 被動維護**
   - 保留給「已在 V1 上且尚未遷移」的既有用戶
   - **不主動修復 V1 bug**（除非是崩潰性，例如 app crash、完全無法登入）
   - **不主動推 V1 用戶轉 V2**（app 內不放升級按鈕、不彈 prompt）
   - V1 code path 列為 `@available(*, deprecated, message: "V1 被動維護")`，但不刪
3. **V2 零容忍品質標準（硬 SLO）**
   - 24h Cloud Logging：V2 用戶 decode failure count = **0**
   - 24h Cloud Logging：V2 用戶打到 V1 endpoint 次數 = **0**
   - 24h Cloud Logging：V2 用戶 `/v2/*` 非 2xx 採**分層 threshold**（決策 1 = C）：
     - 5xx + timeout：count > 5 / 10min → **PagerDuty P0**
     - 4xx（401/403/404 等）：進 dashboard 監控，不 page（屬 client-side 預期錯誤）
   - Crashlytics：V2 用戶因 training-plan module crash = **0**
   - 任一觸發 → 立即 PagerDuty/Slack alert → **當 P0 incident 處理**

---

## 現況評估

### V1 / V2 用戶分布（用戶於 2026-04-17 拍板提供）

- **V1 WAU：100**（7d unique uid 打 `/plan/race_run/*`）
- **V2 WAU：50**（7d unique uid 打 `/v2/*`）
- V2 用戶誤打 V1 的 7d count：38（已知，從 incident log）
- V2 用戶 7d decode failure count：38（已知）
- **獨立受影響 V2 用戶數：6**
- **影響比例：6 / 50 = 12%**（7 天累積，V2 用戶中有 12% 踩到 decode failure）

### 嚴重度：**P0**

依據：
1. V2 是戰略主體，12% base 踩坑屬於不可接受
2. 失敗 path 為 onboarding → overview → weekly，是「新用戶首次體驗」主通道
3. 失敗後 UI 僅顯示 ErrorView，無 retry/fallback，等同完全中斷
4. V1 WAU 是 V2 的 2 倍（100 vs 50），但 V1 被動維護不改；V2 硬化必須立刻動

### V2 路徑目前已知破口

| # | 位置 | 問題 | 影響 |
|---|---|---|---|
| B1 | `OnboardingFeatureViewModel.swift:735` `loadTrainingOverview()` | V2 用戶寫死呼叫 `trainingPlanRepository.getOverview()`（V1） | V2 用戶 onboarding 後 overview decode fail |
| B2 | `OnboardingFeatureViewModel.swift:766` `completeOnboarding()` | V2 用戶寫死呼叫 `trainingPlanRepository.createWeeklyPlan()`（V1） | V2 用戶首週 plan 建立失敗或走錯 backend |
| B3 | `WeeklyPlanViewModel.swift:289` `loadOverview()` | 未注入 V2 Repo，無 Router 分流 | V2 用戶觸發 `/plan/race_run/overview` 404 / decode fail |
| B4 | `WeeklyPlanViewModel.swift:136/185/242/265` weekly/createWeekly/modify/refresh | 同 B3 | V2 用戶 weekly 操作打 V1 endpoint |
| B5 | V1 endpoint 對 V2 用戶回 degraded shape 且被 V1 DTO 嘗試 decode | `APIParser` silent throw，UI 只看到 ErrorView | V2 用戶 decode failure 持續噴，無明確訊號讓 user 或 app 知道 routing 錯了 |
| B6 | `PlanOverviewV2DTO` 與 backend 實際 `/v2/plan/overview` response shape 是否 100% 對齊未驗證（用戶描述「V2 endpoint 回 V3 shape」） | 未知 DTO drift 風險 | 可能潛在 decode failure |

### V2 路徑目前無監控盲區

| # | 盲區 | 後果 |
|---|---|---|
| M1 | 沒有「V2 用戶打到 V1 endpoint」的反向 alert | 再發生類似 routing bug 要等用戶投訴才知道 |
| M2 | 沒有 V2 endpoint 非 2xx rate 的 SLO dashboard | V2 backend 退化無法主動發現 |
| M3 | 沒有鎖定 V2 response schema 的 contract test | backend 改 shape → client 下次 build 才炸，prod 已出事 |
| M4 | 沒有 V2 用戶 onboarding → overview → weekly 全路徑 E2E（Maestro 僅有 `regression-v2-weekly-flow.yaml`，涵蓋範圍需盤點） | 區域迴歸風險高 |
| M5 | 沒有 CI gate：V2 相關 test 失敗仍可 merge | 保護網漏水 |
| M6 | V2 用戶在背景刷新（`TrainingPlanV2ViewModel` cooldown）、訂閱、HealthKit 整合環節是否也有錯誤路由，未獨立驗證 | 未知次生破口 |

---

## 修復與硬化範圍

### A：止血（本週必做，P0）

#### A-0 V2 endpoint shape 實測與 golden fixture（**範圍調整**）

**Architect 偵察更新（2026-04-17）**：
- 現有 fixture 已存在於 `HavitalTests/TrainingPlan/Unit/APISchema/Fixtures/{PlanOverview,PlanStatus,WeeklyPlan,WeeklyPreview,WeeklySummary}/`
- PlanOverview 覆蓋 race_run_paceriz / beginner_10k / maintenance_aerobic / minimal_fields 共 4 份
- WeeklyPlan 覆蓋 paceriz_42k_{base,peak}_week / complete_10k_conversion_week / polarized_42k_build_week / session_wrapper_format / missing_optional_fields / minimal_rest_day_only 共 7 份
- **這些是 test-authored mock，不保證 = prod live shape**
- 核心 gap：需證明「現有 fixture ≡ prod /v2 endpoint 實際 response」，而非從頭生新 fixture

- **誰：** Developer
- **做法（兩段式）：**

  **A-0a 自主可做（不需憑證）**：
  1. 比對現有 fixture 欄位清單 vs `PlanOverviewV2DTO` / `WeeklyPlanV2DTO` / `PlanStatusV2Response` 所有 `CodingKeys`（含 optional）
  2. 比對 V1 incident log 中 decode failure 的實際 JSON payload（從 Cloud Logging 撈 38 筆 failure 中至少 3 筆 raw response body）
  3. 輸出 `HavitalTests/TrainingPlan/Unit/APISchema/Fixtures/SCHEMA_DRIFT_REPORT.md`：逐欄位對照「DTO 定義 / 現有 fixture / prod 實際 response」三欄差異

  **A-0b 需用戶協助（拿 curl 證據）**：
  1. 用戶提供 dev Firebase ID token（`paceriz-dev` 環境）或協助跑 curl 抓三種 target_type 的 `/v2/plan/overview`、對應的 `/v2/plan/weekly/{planId}`、`/v2/plan/status`
  2. Developer 存為 `HavitalTests/.../Fixtures/PlanOverview/prod_live_{race_run,beginner,maintenance}.json` 等（清 PII）
  3. 以這批 live fixture 補跑 decoding test，驗證 DTO 能吃真實資料

- **AC：**
  - [ ] A-0a：SCHEMA_DRIFT_REPORT.md 完成，明列 V3 shape claim 是真是假（逐欄位對照）
  - [ ] A-0b：每 target_type 至少 1 份 prod_live fixture 加入 repo（清 PII）
  - [ ] 現有 decoding tests + 新 prod_live decoding tests 全 pass；若 fail → 開 A-0.5 修 DTO/Mapper/Entity
  - [ ] Prod_live fixture header 註解寫上取樣日期與 backend commit SHA

- **卡點（Architect → 用戶）：**
  - A-0a 可立即開工
  - A-0b 需要用戶提供：(1) dev token 或 curl 協助、(2) 三種 target_type 的測試帳號 uid

#### A-1 `OnboardingFeatureViewModel.loadTrainingOverview()` V2 分流
- **檔案：** `Havital/Features/Onboarding/Presentation/ViewModels/OnboardingFeatureViewModel.swift:730-743`
- **做法：** 用 `TrainingVersionRouter.isV2User()` 分流；V2 → `trainingPlanV2Repository.getOverview()` → 設 `trainingOverviewV2`；V1 → 現行行為
- **AC：**
  - [ ] V2 mock user 呼叫後：`trainingPlanV2Repository.getOverview()` 被呼叫 1 次，`trainingPlanRepository.getOverview()` **0 次**（URLProtocol/mock 驗證）
  - [ ] V1 mock user：反之
  - [ ] `trainingVersion = nil` → 走 V1（向下相容）
  - [ ] 新增 `.tracked(from: "OnboardingFeatureVM: loadTrainingOverview(V2|V1)")`
  - [ ] Unit test：`OnboardingFeatureViewModelTests` 新增 4 case（V2 success / V1 success / V2 repo throw / V1 repo throw）

#### A-2 `OnboardingFeatureViewModel.completeOnboarding()` V2 分流
- **檔案：** 同上 `line 761-780`
- **做法：** V2 用戶完成 onboarding 時呼叫 `trainingPlanV2Repository.createWeeklyPlan(...)`；V1 維持
- **AC：**
  - [ ] V2 mock user onboarding 完成流程中：0 次呼叫 `/plan/race_run/*`（URLProtocol test）
  - [ ] V1 用戶 onboarding flow 不 regress（Maestro `onboarding-race-paceriz.yaml` 仍 pass）
  - [ ] 若 V2 Repo 與 V1 Repo createWeeklyPlan 參數 signature 不同 → 在 Mapper 層轉換，不讓 ViewModel 知道差異

#### A-3 `WeeklyPlanViewModel` 改造
- **檔案：** `Havital/Features/TrainingPlan/Presentation/ViewModels/WeeklyPlanViewModel.swift`
- **做法（兩段式）：**
  - **階段 1（本週）**：在 `loadOverview()`, `getWeeklyPlan`, `createWeeklyPlan`, `modifyWeeklyPlan`, `refreshWeeklyPlan` 入口都加 `if await router.isV2User() { earlyReturn + structuredLog("v2_user_entered_v1_viewmodel") }`。UI state 進入 `.error(DomainError.wrongVersionForPath)`，ErrorView 顯示「版本不一致，請重新啟動」。
  - **階段 2（Task C-1 併入）**：追查「V2 用戶為何進到 `WeeklyPlanViewModel`」的 UI 入口，改導到 `TrainingPlanV2ViewModel`
- **AC（階段 1）：**
  - [ ] V2 mock user 觸發任一方法 → **不**發出任何 `/plan/race_run/*` HTTP（URLProtocol test 強驗證）
  - [ ] Cloud Logging 新增可搜尋的 `v2_user_entered_v1_viewmodel` 事件，含 `uid`、`method`、`stack_context`
  - [ ] V1 用戶行為 unchanged
  - [ ] Spec 註明：階段 2 是「當 alert 觸發 or C-1 執行時」才啟動，不是本 PR 範圍

#### A-4 V1 endpoint decoder 防護罩
- **檔案：** 新增 `Havital/Features/TrainingPlan/Data/Safeguards/V1OverviewVersionGuard.swift` + 整合至 `TrainingPlanRepositoryImpl.getOverview()`、`createWeeklyPlan()`
- **做法：** V1 Repo 每次呼叫前先問 `TrainingVersionRouter.isV2User()`：若 true → **拒絕呼叫 + 丟 `DomainError.wrongVersionForEndpoint`** + structured log `v1_endpoint_blocked_for_v2_user`
- **AC：**
  - [ ] V2 user 呼叫 V1 `getOverview()` 立即 throw，不發出 HTTP
  - [ ] V1 user 不受影響（Maestro V1 flow pass）
  - [ ] Log 事件 key = `v1_endpoint_blocked_for_v2_user`，可在 Cloud Logging query
  - [ ] 不違反 CLAUDE.md「Repository 被動」：Guard 以 decorator/interceptor 方式注入，不是 Repo 自己決定

#### A-5 V1 code path deprecated 標註（不刪）
- **做法：** `TrainingPlanRepository` protocol 與 `TrainingPlanRepositoryImpl` 加
  ```swift
  @available(*, deprecated, message: "V1 被動維護，僅供既有 V1 用戶。新功能一律走 V2（TrainingPlanV2Repository）。")
  ```
  同時標註 `WeeklyPlanViewModel` V1 path、`TrainingPlanView.swift` 等 V1-only View
- **決策：** 決策 3 = C（折衷）→ 本 plan 只做 doc comment，compile warning 延後至 2026-07-17 後
- **AC：**
  - [ ] `TrainingPlanRepository` protocol、`TrainingPlanRepositoryImpl`、`WeeklyPlanViewModel`、`TrainingPlanView` 加 doc comment `/// @deprecated V1 被動維護，新功能請走 V2（TrainingPlanV2Repository）。預計 2026-07-17 後升級為 compile warning。`
  - [ ] 新增 `docs/architecture/v1-deprecation-policy.md`（與 D-1 合併產出）
  - [ ] 不啟用 `@available(*, deprecated, ...)`（避免本 plan 額外噪音）
  - [ ] 建 follow-up task：「2026-07-17 review V1 call site 數量，決定是否升 compile warning」

---

### B：零容忍基礎建設（兩週內，P0）

#### B-1 V2 Contract Test（鎖住 schema drift）
- **檔案：** 新增 `HavitalTests/TrainingPlan/Contract/V2ContractTests.swift`
- **做法：** 讀 A-0 的 5 份 golden fixture，跑 `JSONDecoder().decode(DTO.self, from: fixture)`；每個 required 欄位 rename/刪除 test 必紅
- **AC：**
  - [ ] 5 個 fixture 全 decode pass
  - [ ] Mutation test：手動從 fixture 移除 `id` / `target_type` / `total_weeks` 其中之一 → test fail
  - [ ] 接上 CI（見 B-5）

#### B-2 V2 用戶 Maestro E2E flows
- **做法：** 新增或擴充：
  - `.maestro/flows/v2-onboarding-race-run-happy.yaml`
  - `.maestro/flows/v2-onboarding-beginner-happy.yaml`
  - `.maestro/flows/v2-onboarding-maintenance-happy.yaml`
  - `.maestro/flows/v2-daily-weekly-ops.yaml`（一般日常：進 overview → 看 weekly → 修改 → 離開 → 再進）
  - 每條 flow 結尾檢查 UI 無 ErrorView、無 "decode failed" debug 字串
- **依賴：** 需要 demo-login 能切到 V2 用戶帳號——本 Task 內若缺則擴充 `logout-and-demo-login.yaml` 或新增 `switch-to-v2-demo-user.yaml`
- **AC：**
  - [ ] 4 條 flow 在 iPhone 17 Pro pass（有 recording）
  - [ ] 既有 V1 Maestro flows（`onboarding-race-paceriz` 等）仍 pass
  - [ ] 每條 flow 在首 step 加 `assertVisible` 驗證當前 `trainingVersion = "v2"` 的 UI 訊號（如 debug banner 或 V2-only 元素）

#### B-3 Cloud Logging Alerts（V2 零容忍 SLO）
- **做法：** 在 GCP Cloud Monitoring 建三條 alert policy（需要 Architect + Backend 協作，不直接落 code）：
  - **Alert #1**：`APIParser` error where `log_type = "v1_v2_version_mismatch"` OR client event `v1_endpoint_blocked_for_v2_user` count > 0 within 5min → PagerDuty P0
  - **Alert #2**：`/v2/*` endpoint non-2xx rate > threshold（決策點 1）over 10min → P0
  - **Alert #3**：`training_version="v2"` 的 user request 打到 `/plan/race_run/*` count > 0 within 5min → P0
- **AC：**
  - [ ] 3 條 alert policy 建立，Slack #incidents channel 可收
  - [ ] 在 test 環境手動觸發每條 alert 各一次（人為產生 log），驗證 alert fires
  - [ ] Runbook 寫在 `docs/incidents/v2-alerts-runbook.md`：每條 alert 觸發後的 triage 步驟

#### B-4 V2 SLO Dashboard
- **做法：** Cloud Monitoring dashboard 記錄：
  - V2 用戶 7d decode failure count（目標 0）
  - V2 用戶 7d 打 V1 endpoint count（目標 0）
  - `/v2/*` 2xx rate（目標 > 99.9% or threshold）
  - V2 active users 7d
- **AC：**
  - [ ] Dashboard URL 記錄到 `docs/observability/v2-slo-dashboard.md`
  - [ ] 每週 Architect review 一次（新增進 `.claude/rules` 或排程）

#### B-5 CI Gate
- **做法：** 在 GitHub Actions workflow 加：
  - V2 相關 Unit + Contract test 路徑失敗 → block merge（required check）
  - `v2-onboarding-*` Maestro flows 在 PR 有 V2 相關 diff 時必跑（可用 path filter）
- **AC：**
  - [ ] PR workflow file diff 可看到 required checks
  - [ ] 故意把 `PlanOverviewV2DTO.id` 刪掉開 PR 驗證會紅
  - [ ] 原本綠的 PR 不受影響

---

### C：V2 路徑全覆蓋（一個月內，P1）

#### C-1 V2 用戶所有觸發路徑盤點
- **做法：** Architect + Developer 共同列出 V2 用戶在 app 內所有可觸發的：
  - HTTP endpoint（預期應全為 `/v2/*` 或共用 endpoint 如 `/user/profile`、`/subscription/*`、`/announcement/*`）
  - Firestore path（`plans/{uid}/v2/*`、`weekly_summaries/*` 等）
  - Background refresh / cooldown 路徑（`CooldownResource`）
  - Subscription 整合路徑（RevenueCat → `/subscription/*`）
  - HealthKit 上傳路徑（`AppleHealthWorkoutUploadService`）
- **產出：** `docs/architecture/v2-user-path-inventory.md`（表格：path / owner / 是否已有 test / 是否已有 alert）
- **AC：**
  - [ ] Inventory 覆蓋每個 V2 用戶 1 天內可能觸發的 code path
  - [ ] 每條 path 標記 test + alert 覆蓋狀態
  - [ ] 缺口（✗）項目開成 follow-up task

#### C-2 每條路徑 Contract + Maestro 覆蓋補齊
- **做法：** 根據 C-1 的 ✗ 項目，逐條補 contract test + Maestro
- **AC：**
  - [ ] Inventory 所有 path 都 ✓（或明確標「不需要，原因：___」）

#### C-3 SpecCompliance 覆蓋率 ≥ 80%
- **做法：** V2 相關 SPEC（`docs/specs/SPEC-*v2*`、`training-plan-versioning` L2 entity 下所有 doc）每條 AC 掛對應自動化測試，建立 `HavitalTests/SpecCompliance/V2SpecComplianceTests.swift` 彙整
- **AC：**
  - [ ] Spec 覆蓋率腳本輸出 ≥ 80%
  - [ ] 報告進 CI 每週產出

#### C-4 Integration Test：URLProtocol 攔截 V2 routing 全檢
- **檔案：** 新增 `HavitalTests/Integration/Routing/V2UserRoutingTests.swift`
- **做法：** Mock V2 用戶，跑所有 ViewModel 入口，斷言 0 次觸發 `/plan/race_run/*`
- **AC：**
  - [ ] Test pass
  - [ ] Test case list 涵蓋 C-1 inventory 的每個 endpoint 入口

---

### D：V1 被動維護規範（文件化）

#### D-1 V1 Deprecation Policy 文件
- **檔案：** `docs/architecture/v1-deprecation-policy.md`
- **內容：**
  - V1 code 列為 @deprecated 但不刪（理由、移除時機）
  - V1 bug triage 規則：崩潰性（app crash / 無法登入 / 付費異常）→ 修；其他 → 記入 `docs/05-sprints/v1-known-issues.md` 不動
  - 不加新 V1 功能、不主動推遷移
  - V1 用戶在 app 內**不顯示**「升級到 V2」的 UI（不推、不催）
  - V1 用戶自然流失監控：Dashboard 追蹤 V1 active user 月減少率
- **AC：**
  - [ ] 文件入 repo
  - [ ] 在 `CLAUDE.md` 或 `.claude/rules/architecture.md` 連結到該文件
  - [ ] 加入「V1 bug 進 triage」到 `.claude/rules/debugging.md` 的 Failure Classification 段

#### D-2 Triage SOP 新增 V1/V2 分類
- **做法：** 在 `.claude/rules/debugging.md` 加表格欄位：
  ```
  | Category | Definition | V1 Action | V2 Action |
  |---|---|---|---|
  | App crash | ... | Fix | Fix + P0 |
  | Decode failure | ... | Log only, no fix | Fix + P0 |
  | UX degraded | ... | Log only, no fix | Fix + P1 |
  ```
- **AC：**
  - [ ] rules 檔更新

---

## 修改清單 Summary（QA 逐條 check 用）

| ID | 類別 | 檔案/產出 | Owner | 優先級 |
|---|---|---|---|---|
| A-0 | 止血 | V2 golden fixture x5 | Developer | P0 |
| A-1 | 止血 | OnboardingFeatureVM.loadTrainingOverview | Developer | P0 |
| A-2 | 止血 | OnboardingFeatureVM.completeOnboarding | Developer | P0 |
| A-3 | 止血 | WeeklyPlanVM early-return + log | Developer | P0 |
| A-4 | 止血 | V1 Guard interceptor | Developer | P0 |
| A-5 | 止血 | V1 @deprecated 標註 | Developer | P0 |
| B-1 | 硬化 | V2 Contract tests | Developer + QA | P0 |
| B-2 | 硬化 | V2 Maestro flows x4 | QA | P0 |
| B-3 | 硬化 | 3 條 Cloud Alert | Architect + Backend | P0 |
| B-4 | 硬化 | V2 SLO dashboard | Architect | P0 |
| B-5 | 硬化 | CI required check | Developer | P0 |
| C-1 | 全覆蓋 | V2 path inventory doc | Architect | P1 |
| C-2 | 全覆蓋 | 補齊 test + Maestro | QA | P1 |
| C-3 | 全覆蓋 | SpecCompliance ≥ 80% | Developer + QA | P1 |
| C-4 | 全覆蓋 | URLProtocol 全檢 | QA | P1 |
| D-1 | 文件 | V1 deprecation policy | Architect | P1 |
| D-2 | 文件 | Triage SOP 更新 | Architect | P1 |

---

## 驗收 Gate

### 部署前
- [ ] A-0 ~ A-5 全部 AC 打勾
- [ ] B-1 ~ B-5 全部 AC 打勾
- [ ] `xcodebuild clean build ... iPhone 17 Pro` 零錯誤
- [ ] V1 Maestro flows pass（regression）
- [ ] V2 Maestro flows pass（4 條）
- [ ] Contract tests pass
- [ ] `/simplify` 執行並附紀錄
- [ ] QA Verdict PASS

### 部署後 24h（V2 零容忍驗證）
- [ ] Cloud Logging：`training_version="v2"` 用戶 decode failure = **0**
- [ ] Cloud Logging：`training_version="v2"` 用戶打到 `/plan/race_run/*` = **0**
- [ ] Cloud Logging：`/v2/*` 非 2xx rate ≤ **threshold（決策 1）**
- [ ] Crashlytics：V2 用戶 training-plan module crash = **0**
- [ ] `v1_endpoint_blocked_for_v2_user` event = 0（證明 A-1/A-2/A-3 修好了，Guard 沒觸發才對）
- [ ] V1 用戶 `/plan/race_run/overview` 200 rate 不 regress

任一條不符 → **立即回滾** + incident review，不 debate。

### 部署後 7d
- [ ] 重跑 B-4 dashboard 7d window 全部綠
- [ ] C-1 inventory 可動工

---

## 風險與不確定性

### 1. 不確定的技術點
- **V2 endpoint 實際 shape**：A-0 gate 必過。沒做完 A-0 不開 A-1。
- **V2 用戶為何進入 `WeeklyPlanViewModel`**：Cloud log 顯示確有 V2 user 打 V1 weekly endpoint，表示某 UI 路徑直接建了 `WeeklyPlanViewModel`。A-3 階段 1 用 early-return 止血，C-1 inventory 找根源。
- **Deprecation warning 是否會讓 pre-existing V1 call site 產生大量噪音**：A-5 若選啟用 compile warning，可能 30+ warnings，需評估是否用 `@_spi` 或 module-level suppression。

### 2. 替代方案與選擇理由
- **替代 A：Backend 讓 V1 endpoint 對 V2 user 回 410 Gone**
  - 優點：server-side 防禦 + 明確
  - 缺點：需 backend 配合 + 時程不可控；且 client A-4 Guard 已能達到同效果
  - 選擇：**列為 follow-up ticket 建議，本 plan 不 block**
- **替代 B：一次把 `WeeklyPlanViewModel` 改成真正支援 V2**
  - 缺點：scope 大、風險高、duplicate `TrainingPlanV2ViewModel`
  - 選擇：**A-3 階段 1 止血 + C-1 找入口導向 V2 ViewModel**
- **替代 C：完全拔除 V1 code**
  - 缺點：違反戰略前提（V1 被動維護）
  - 選擇：**駁回**

### 3. 需要用戶確認的決策（見下方 Decision Points）

### 4. 最壞情況與修正成本
- **最壞**：A-0 發現 V2 endpoint shape 與 DTO 嚴重 drift → A-0.5 展開，延後 A-1 1-2 天
- **次壞**：A-3 early-return 導致少量 V2 用戶看到錯誤畫面（本來就壞，變 explicit）；修正成本中（C-1 補齊入口）
- **Rollback**：client-only 改動 → 下架新版本 + 確保 1.2.3 binary 歸檔；backend 0 改動
- **誤報**：A-4 Guard 可能誤判（User 資料尚未 bootstrap 完成時 `trainingVersion` 為 nil → default V1）。需在 Router 的 `isV2User()` 邏輯嚴格保證 cache-first + 同步讀取，不能在 cold start race。A-4 要附 unit test 覆蓋 bootstrap timing。

---

## Out of Scope（本 plan 不做）

- Backend V1 endpoint 回 410 Gone（建議另開 ticket）
- V1 用戶主動遷移 V2 的 UI flow（戰略不允許）
- 強制 Version Gate 426→XXX 升級（**Task #5 追蹤**，不 block 本 plan）
- `TrainingPlanV2ViewModel` 本身功能擴充
- V3 naming 正式化（若 V2 endpoint 真回 V3 shape，只是語意，不改 struct name）

---

## 決策（2026-04-17 用戶拍板）

### 決策 1：V2 `/v2/*` 非 2xx threshold → **C（分層）**
- 5xx + timeout：count > 5 / 10min → PagerDuty P0
- 4xx：進 dashboard，不 page
- 理由：誤報最少，區分 server-side 問題與 client-side 預期錯誤
- **落點：** B-3 Alert #2、部署後 24h 驗證 SLO、「零容忍品質標準」章節

### 決策 2：Contract test fixture 來源 → **C（dev 帳號 curl）**
- 方法：用 `paceriz-dev` 環境，建立三種 target_type 的 V2 用戶，分別 curl `/v2/plan/overview`、`/v2/plan/weekly/{planId}`
- 無 PII、可重複、自主性高
- **落點：** A-0 執行方法

### 決策 3：V1 @deprecated → **C（折衷：先 doc，3 個月後升 warning）**
- Phase 1（本 plan 範圍）：只用 doc comment `/// @deprecated V1 被動維護` + 寫進 `docs/architecture/v1-deprecation-policy.md`
- Phase 2（2026-07-17 後，由 Architect review）：升級為 `@available(*, deprecated, ...)` compile warning
- **落點：** A-5 AC 改為「用 doc comment + 進 policy 文件，compile warning 延後到 Q3」

### 決策 4：強制升級 Version Gate 426→XXX → **是，但另開 ticket**
- 本 plan 不 block；追蹤於 Task #5
- **落點：** Out of Scope 章節註明「Task #5 追蹤」
