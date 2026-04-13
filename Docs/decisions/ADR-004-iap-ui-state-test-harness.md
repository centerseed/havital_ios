---
type: ADR
id: ADR-004
status: Draft
ontology_entity: iap-subscription
created: 2026-04-10
updated: 2026-04-10
---

# ADR-004: IAP UI 狀態測試 Harness 與 Admin API 模擬策略

## Context

iOS 端已完成訂閱狀態查詢、`SubscriptionStateManager`、Profile 訂閱區塊、paywall trigger 與 RevenueCat 基礎整合，但目前缺少一個可重複執行的測試控制平面，讓 QA / Maestro / XCUITest 能穩定驗證「後端訂閱狀態變了之後，App UI 是否正確反映」。

現有能力與限制如下：

- `SubscriptionRepositoryImpl` 已支援 `clearCache()`、`refreshStatus()` 與 `SubscriptionStateManager` 更新，代表只要後端狀態被正確改動，App 端理論上已具備刷新 UI 的核心能力。
- `UserProfileView` 已有 DEBUG-only developer section，也已顯示 `trial`、`active`、`expired`、`billing_issue` 等訂閱 UI，適合作為手動測試入口。
- `HavitalApp` 在偵測 `XCTestCase` 時會直接顯示 `Running Tests...`，這會阻斷任何想驗證真實訂閱 UI 的自動化測試。
- 後端 `SPEC-iap-subscription`、`ADR-005-iap-test-strategy` 與 `DEV-IAP-DARK-DEPLOYMENT-TESTING-GUIDE` 已明確要求：
  - `dev` 階段用 `iap_enabled=false` + `iap_test_uids` allowlist 做 dark deployment。
  - `Cv5ADE73tiZMpEyD80Yh1BAqYch2` 這類 tester UID 需要能被隔離測試。
  - Admin rescue flow 必須驗證 `override / extend / set-expires` 後，受測帳號真的會通過或被 gate 擋下，而不是只驗 payload。

核心問題因此不是「App 有沒有訂閱 UI」，而是「如何在不把高權限能力外洩到正式產品路徑的前提下，建立一套能從 App 端驅動 Admin API、改變測試 UID 訂閱狀態、再觀察真實 UI 行為的測試機制」。

## Decision

**統一採用 DEBUG-only 的 `IAP Test Harness`，由 App 端以受控方式呼叫 `dev` 的 Admin API 修改指定 tester UID 的訂閱狀態，並在每次操作後強制刷新本機訂閱狀態，讓手動測試與自動化 UI 測試共用同一套控制平面。**

具體決策如下：

1. **統一建立單一測試控制平面，而不是讓 Maestro / XCUITest / 手動 QA 各自用不同腳本。**
   App 端新增 `IAPTestHarness`（DEBUG-only），負責三件事：
   - 呼叫 `dev` 環境的 Admin API 修改指定 tester UID 訂閱狀態
   - 在操作成功後執行 `SubscriptionRepository.clearCache()` + `refreshStatus()`
   - 將操作結果、當前訂閱狀態與最後一次 API 響應顯示在 debug UI，供人工與自動化共用

2. **統一只允許在 `DEBUG + dev + allowlisted tester UID` 下操作，不允許一般產品路徑直接持有可變更任意用戶訂閱狀態的能力。**
   `IAPTestHarness` 只在以下條件成立時啟用：
   - `#if DEBUG`
   - App 指向 `dev` backend
   - 受測 UID 在 allowlist 中，第一個預設 UID 為 `Cv5ADE73tiZMpEyD80Yh1BAqYch2`
   - Admin API token / session 由 launch arguments、`xcconfig`、或本地 debug 設定注入，不得 hardcode 進 source，也不得包入 production build

3. **統一以現有 Admin API 契約作為狀態模擬入口，不額外在 App 側發明假資料注入。**
   App 測試入口以後端真實資料流為準，優先使用下列 endpoint：
   - `GET /api/v1/admin/subscription/{uid}`
   - `POST /api/v1/admin/subscription/{uid}/override`
   - `POST /api/v1/admin/subscription/{uid}/extend`
   - `POST /api/v1/admin/subscription/{uid}/set-expires`
   - `GET /api/v1/admin/subscription/{uid}/history`

   其中狀態模擬規則統一為：
   - 模擬 `expired`：呼叫 `override` 或 `set-expires`，讓狀態進入 `expired`
   - 模擬 `subscribed`：呼叫 `override` 設為 `subscribed` 或 `set-expires` 設未來時間
   - 模擬 `trial_active`：優先用 `extend` 或清除 override 後重走真實 trial path，不在 App 端偽造 trial DTO
   - 模擬 `billing_issue=true`：若後端已有對應 admin mutation，直接呼叫；若尚無，標記為 [未確認]，在第一版 ADR 中先列為 blocked 測項，不假造 client-side flag

4. **統一將自動化入口分成兩層：App 內 debug console + 可腳本化的 launch/deeplink contract。**
   - 手動 QA：從 `UserProfileView` 的 developer section 進入 `IAP Test Console`
   - 自動化測試：提供 launch arguments 或 deeplink 觸發同一套 harness，例如：
     - `-iapTestMode`
     - `-iapTestUID Cv5ADE73tiZMpEyD80Yh1BAqYch2`
     - `-iapScenario expired`
     - `havital://debug/iap?action=override_expired&uid=Cv5ADE73tiZMpEyD80Yh1BAqYch2`

   Maestro / XCUITest 只負責驅動這些入口，不直接在測試腳本中重複實作 Admin API 細節。

5. **統一把訂閱 UI 測試分成「狀態切換測試」與「功能 gate 測試」兩類，不把它退化成只有 Profile 畫面文字驗證。**
   第一版必測矩陣如下：
   - `expired`：Profile 顯示 expired；受限功能進入 paywall 或顯示正確 gate UI
   - `subscribed`：Profile 顯示有效訂閱；原本被擋的功能恢復可用
   - `trial_active`：Profile 顯示 trial 剩餘天數；受限功能可用
   - `billing_issue=true`：Profile 或入口顯示黃色提示，但功能不阻擋
   - `override clear`：解除 override 後，狀態恢復以後端真實計算為準

6. **統一先修正 `HavitalApp` 的測試啟動路徑，不再讓 UI 自動化落在 `Running Tests...` 空畫面。**
   `XCTest` / Maestro 模式下，App 應允許進入真實 UI，只跳過不必要的系統權限或 onboarding 重置；不得用單一 placeholder view 取代整個 App。

## Alternatives

| 方案 | 優點 | 缺點 | 為什麼不選 |
|------|------|------|-----------|
| 只用 Maestro 腳本在 App 外部呼叫 curl / admin API，再回到 App 驗畫面 | 實作看似最快，不需加 app code | 手動 QA 與自動化流程分裂；每支腳本都重複實作 admin 認證與狀態刷新；App 端無法顯示操作結果與診斷資訊 | 不利長期維護，也無法形成共用測試控制平面 |
| 直接在 App 端注入假的 subscription DTO，不打後端 | 實作快、完全離線 | 驗不到真實 cache / refresh / backend contract / gate behavior；容易變成「畫面測試都綠，但真實整合錯」 | 與 ADR-005 的 scenario-based coverage 原則衝突 |
| 將正式 super-admin credential hardcode 在 DEBUG app 裡，直接打任意 Admin API | 操作最直接 | 安全風險過高；debug build 外流就等於暴露高權限寫入能力；也無法限制測試 UID 範圍 | 不接受把高權限憑證作為產品資產的一部分 |
| 完全不做 App 內 harness，只靠後端 release checklist 手動驗收 | 文件成本低 | 無法支撐頻繁迭代的 UI regression；每次都要人工組裝測試條件，速度慢且不可重複 | 不足以作為 iOS IAP UI 的日常 guardrail |

## Consequences

- 正面：手動 QA、Maestro、XCUITest 共用同一套狀態模擬與刷新邏輯，測試結果更一致。
- 正面：測試流程改走真實後端資料流，可直接驗證 `override / extend / set-expires` 對 App UI 的實際影響，而不是只驗 mock state。
- 正面：developer section 會變成可觀察的訂閱測試面板，有助於定位「後端已改狀態，但 app 沒刷新」這類整合問題。
- 負面：需要補一層 DEBUG-only 基礎設施，包括 token 注入、UID allowlist、deeplink/launch contract 與測試專用 UI。
- 負面：若現有 Admin API 認證模型過於偏向後台 Web，iOS debug harness 可能需要額外的 dev-only auth support。
- 後續處理：補一份對應 `TEST` 文件，把 `expired / subscribed / trial / billing_issue / override clear` 各場景寫成 Given/When/Then。
- 後續處理：補一份 Maestro flow 規格，明確哪些步驟由 App 內 harness 執行，哪些步驟由 UI 驗證負責。
- 後續處理：若後端尚未提供可安全給 debug app 使用的測試型 admin auth，需另開後端決策補齊；目前此點標記為 [未確認]。

## Implementation

1. 新增 `ADR-004-iap-ui-state-test-harness.md`，定義 iOS IAP UI 測試的控制平面與安全邊界。
2. 在 iOS 端新增 DEBUG-only `IAPTestHarness` / `IAPTestAdminClient`：
   - 封裝 `dev` Admin API 呼叫
   - 限制 tester UID allowlist
   - 管理操作後的 `clearCache()` + `refreshStatus()`
3. 在 `UserProfileView` 的 developer section 新增 `IAP Test Console`：
   - 顯示當前受測 UID
   - 提供 `expired`、`subscribed`、`trial`、`clear override`、`refresh status` 操作
   - 顯示最近一次操作結果與目前訂閱狀態
4. 為自動化測試新增可腳本化入口：
   - launch arguments 或 deeplink contract
   - 測試模式下允許進入真實 App UI
   - 移除或改寫 `Running Tests...` placeholder gating
5. 建立第一版測試矩陣：
   - Profile 訂閱顯示
   - paywall / gate UI
   - billing issue 黃色提示
   - 狀態切換後的即時刷新
6. 後續補 `TEST-iap-ui-state-harness` 文件與 Maestro/XCUITest flows，將本 ADR 的決策轉成可執行驗收場景。
