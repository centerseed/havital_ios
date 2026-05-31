---
spec:
  - apps/ios/Havital/Docs/specs/SPEC-paywall-rewrite.md (AC-PAYWALL-32 ~ 36)
  - cloud/api_service/docs/01-specs/SPEC-iap-subscription.md (P0-16 ~ 18)
created: 2026-04-27
status: in-progress
owner: agent:architect
---

# PLAN: IAP Pre-Review Hardening

## Goal

把上 App Store 審查前的 P0 阻擋風險全部修掉，加上一個「免費體驗期」UX 提示，並補強 webhook 認證安全性。修完後跑 TestFlight sandbox 完整驗證再送審。

## Scope（用戶確認 2026-04-27）

採 S3 + F4：

| F# | 項目 | 對應 AC | 工時 |
|---|---|---|---|
| F1 | Paywall disclosure 加 Privacy + Terms 可點擊連結 | AC-PAYWALL-32, AC-PAYWALL-33 | 0.25 天 |
| F2 | Paywall 顯示精確試用結束日期（三語）| AC-PAYWALL-34 | 0.25 天 |
| F3 | Webhook security hardening（constant-time + UID 驗證 + alert）| P0-16, P0-17, P0-18 | 1 天 |
| F4 | Free tier UI（主頁 banner + 設定頁 tier 標示）| AC-PAYWALL-35, AC-PAYWALL-36 | 1.5 天 |
| F5 | Sandbox 驗證 SOP 文件 | （不是 AC，是驗證 deliverable）| 0.5 天 |

**延後上線後補（v+1）**：appAccountToken 整合、GRACE_PERIOD_EXPIRED handler、PRICE_INCREASE handler、Refund race condition、Trial refund + repurchase 邊界

## Tasks

- [ ] **T0**: SPEC 更新（Architect）
  - Files: `apps/ios/Havital/Docs/specs/SPEC-paywall-rewrite.md`, `cloud/api_service/docs/01-specs/SPEC-iap-subscription.md`
  - 加 AC-PAYWALL-32 ~ 36 + P0-16 ~ 18
  - i18n key 表新增對應 entries
- [ ] **T1**: iOS F1 + F2 — Disclosure 連結 + 試用結束日期（iOS Developer）
  - Files: `Havital/Features/Subscription/Presentation/Views/PaywallView.swift`, `Havital/Resources/Localizations/{zh-TW,en-US,ja-JP}.lproj/Localizable.strings`
  - Done Criteria：
    - Disclosure 區用 AttributedString 包含可點擊「隱私政策」「服務條款」連結
    - Tap 連結 → 用 `SFSafariViewController` 開啟（不要 in-app WebView）
    - Yearly card focus 時 disclosure 包含具體試用結束日期（用 `DateFormatter` locale-aware）
    - 三語各有對應 i18n keys（zh-TW / en-US / ja-JP）
    - AC-PAYWALL-32 / 33 / 34 對應 test 從 fail 變 pass
    - Clean build 通過（iPhone 17 Pro destination）
  - Verify: `xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- [ ] **T2**: iOS F4 — Free tier UI（iOS Developer，T1 完成後）
  - Files: 新檔 `Havital/Features/Subscription/Presentation/Views/FreeTierBanner.swift`、整合到主頁、設定頁 Subscription 區
  - Done Criteria：
    - 未訂閱 + 已生 Week 1 課表 user 主頁頂部顯示 Free tier banner（標題 + 副標 + 升級 CTA）
    - 訂閱中 / Apple intro trial 中用戶**不顯示** banner
    - 設定頁 Subscription 區顯示「目前方案：Free 免費體驗版」+ 升級至完整版 CTA（未訂閱時）
    - Banner 點擊 / 設定頁 CTA → 開啟 paywall sheet（用 `source=free_tier_banner` / `source=settings_tier`）
    - 三語齊備
    - AC-PAYWALL-35 / 36 對應 test 從 fail 變 pass
    - Clean build 通過
- [ ] **T3**: Backend F3 — Webhook security hardening（Backend Developer，可與 T1 並行）
  - Files: `cloud/api_service/domains/subscription/services/webhook_service.py`, `cloud/api_service/api/v1/subscription.py`（webhook endpoint）, `tests/spec_compliance/test_iap_security_ac.py`（新檔）
  - Done Criteria：
    - `verify_authorization` 改用 `hmac.compare_digest`（防 timing attack）
    - `process_event` 入口處驗證 `app_user_id` 是現有 Firebase UID（不存在 → 返回 `{"status": "rejected", "reason": "unknown_user"}` 並 log warning）
    - 認證失敗 / UID 不存在 / payload 結構錯誤 → 結構化 logging（含 client IP、event_id、event_type）
    - P0-16 / 17 / 18 對應 test 從 fail 變 pass
    - 既有 webhook test（`test_valid_secret_passes` 等）仍 PASS
    - `./unitest.sh dev --skip-llm` 通過（only run affected scope per TESTING_MAP.md）
  - Verify: `pytest tests/spec_compliance/test_iap_security_ac.py tests/unit/domains/subscription/test_webhook_service.py -v`
- [ ] **T4**: Architect 交付審查 + QA dispatch（T1+T2+T3 完成後）
  - Architect 審 Completion Reports，每條 Done Criteria 對應證據
  - 不合格 → 重派 Developer
  - 合格 → 派 QA 跑 AC tests + 手動場景測試
- [ ] **T5**: Sandbox 驗證 SOP 文件（Architect）
  - File: `apps/ios/Havital/Docs/plans/PLAN-iap-pre-review-sandbox-sop.md`
  - 含 Week 1 → Week 2 paywall → 訂閱 → backend sync → 取消 → restore 全路徑測試步驟
  - 用戶照表跑 30-60 分鐘
- [ ] **T6**: 用戶 sandbox 驗證
  - 用戶照 T5 SOP 跑完整流程
  - 任何 fail → 回到 Developer 修
- [ ] **T7**: Architect 最終 AC sign-off + 用戶 build 上 App Store Connect 送審
- [x] **T8**: Bug 3 — 訂閱成功後 banner 不消失二次修復（Architect hotfix）
  - Files: `Havital/Features/Subscription/Data/Repositories/SubscriptionRepositoryImpl.swift`, `HavitalTests/Features/Subscription/Data/SubscriptionRepositoryPollingTests.swift`
  - Done Criteria：
    - RevenueCat optimistic active 後，30 秒 webhook reconcile window 內，generic `refreshStatus()` 不得用 stale backend `.none/.expired` 覆寫 `SubscriptionStateManager`
    - backend 確認 `.active/.trial/.cancelled/.gracePeriod` 時，必須接受 backend 權威狀態並寫 cache
    - hold 過期後，backend `.none/.expired` 必須可正常降級，避免永久掩蓋真實過期
    - Targeted XCTest PASS
  - Verify:
    - `xcodebuild test -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:HavitalTests/SubscriptionRepositoryPollingTests`
    - `xcodebuild test -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:HavitalTests/PaywallViewModelTests`
- [x] **T9**: Bug 4 — 年訂顯示成月訂 backend SKU mapping 修復（Architect hotfix）
  - Files: `cloud/api_service/domains/subscription/constants.py`, `cloud/api_service/tests/unit/domains/subscription/test_webhook_service.py`
  - Done Criteria：
    - `paceriz.sub.monthly.eb1` 正規化為 `monthly`
    - `paceriz.sub.yearly.eb1` 正規化為 `yearly`
    - RENEWAL / PRODUCT_CHANGE webhook 帶 early-bird yearly SKU 時會覆寫舊的 `plan_type=monthly`
  - Verify:
    - `.venv/bin/pytest -q tests/unit/domains/subscription/test_webhook_service.py`
- [x] **T10**: 支援客服辨識早鳥方案（Architect hotfix）
  - Files: `Havital/Views/UserProfileView.swift`, `Havital/Resources/{zh-Hant,en,ja}.lproj/Localizable.strings`, `cloud/api_service/domains/subscription/{constants.py,models/subscription_status.py,services/webhook_service.py,services/subscription_service.py}`, `cloud/api_service/tests/unit/domains/subscription/{test_webhook_service.py,test_subscription_service.py}`
  - Done Criteria：
    - Settings / Profile 方案顯示可區分 `年訂閱（早鳥）` / `月訂閱（早鳥）`
    - backend webhook 對 `paceriz.sub.*.eb1` 寫入 `is_early_bird=true`
    - status API 優先使用 status doc 的 `is_early_bird`，不依賴已棄用的 `early_bird_deadline`
    - 指定 prod UID `E4IU0VafRAdlNXoVHFzN0LZmOZ82` 已補 `is_early_bird=true`
  - Verify:
    - `.venv/bin/pytest -q tests/unit/domains/subscription/test_webhook_service.py tests/unit/domains/subscription/test_subscription_service.py::TestEarlyBird`
    - `xcodebuild build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

## Decisions

- **2026-04-27**: F3 從「JWS payload verification」改成「security hardening 三件事」。理由：RevenueCat webhook 不送 JWS / HMAC payload signature，原 audit 報告的分類不適用此架構。改成 constant-time auth + UID 驗證 + 結構化 logging 是真正有效的防護。
- **2026-04-27**: F4 banner 文案用「免費體驗期」而不是「試用課表」。理由：避免跟 Apple 30 天 Introductory Offer「免費試用」語意混淆。
- **2026-04-27**: F1 連結 tap 用 `SFSafariViewController` 而不是 in-app WebView。理由：簡單、Apple 接受、體驗夠好。
- **2026-04-27**: 試用結束日期用 locale-aware `DateFormatter`（i18n 友善），不寫死月/日格式。
- **2026-04-27**: Bug 3 root cause 補充：第一輪只保護 `waitForBackendAuthorizedStatus()` polling，沒有保護 App foreground / app active / quota check 這些 generic `refreshStatus()`。購買後 Apple sheet dismiss 可能立刻觸發 foreground refresh，後端尚未收到 webhook 時回 `.none/.expired`，導致 optimistic active 被覆寫，banner 繼續顯示。決策：在 `SubscriptionRepositoryImpl` 加 30 秒 in-memory optimistic authorization hold，只擋 stale inactive backend，不擋 backend active 權威確認，也不擋 hold 過期後真降級。
- **2026-04-27**: Bug 4 root cause：iOS / RevenueCat 使用 early-bird SKU `paceriz.sub.yearly.eb1`，但 backend `REVENUECAT_PRODUCT_PLAN_MAP` 未列入 eb1 SKU。若用戶原本/測試狀態殘留 `plan_type=monthly`，RENEWAL 未識別 product id 時不會覆寫 plan_type，Settings 仍顯示月訂。決策：backend mapping 加入 early-bird monthly/yearly SKU，並用 webhook unit test 鎖住 RENEWAL / PRODUCT_CHANGE。
- **2026-04-27**: 早鳥顯示決策：客服判讀不應只看 `plan_type`，需看 `plan_type + is_early_bird`。`early_bird_deadline` 已在 IAP spec alignment 中被棄用，因此 backend 改為 webhook 依 eb1 product id 寫入 `is_early_bird`，status API 讀 doc 欄位優先。

## Resume Point

T8 Bug 3 二次修復、T9 Bug 4 backend SKU mapping、T10 早鳥方案顯示已完成並通過 targeted tests。下一步：部署 backend + 發 TestFlight 後，用 sandbox tester 走真實 purchase flow，確認 banner 在購買成功後立即消失，且 Settings 顯示年訂閱（早鳥）；Bug 2 仍需未用過 intro offer 的 sandbox tester 驗證 Apple confirmation sheet 是否顯示 30 天免費試用。

## Out of Scope（明確記錄延後）

| 項目 | 為什麼延後 | 預計處理時機 |
|---|---|---|
| appAccountToken 加入購買流程 | 罕見邊界（reinstall + 換 Firebase auth），現 RC linking 多數 OK | v+1 |
| GRACE_PERIOD_EXPIRED webhook handler | RC 不太會送，等實際 incident 補 | v+1（如有 incident）|
| PRICE_INCREASE webhook handler | 同上 | v+1（如有 incident）|
| Refund race condition（用戶 refund 立刻關 App）| 影響面極小 | v+1 |
| Trial refund + 立即 repurchase 邊界 | 極少見場景 | v+1 |
| RC IP allowlist | ops 層工作不是 code change | 部署管理 |
| 定期輪替 webhook secret | ops 層 | 部署管理 |
