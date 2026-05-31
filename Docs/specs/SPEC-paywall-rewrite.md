---
type: SPEC
id: SPEC-paywall-rewrite
status: Draft
related_designs:
  - TD-paywall-rewrite
related_acs: []
created: 2026-04-26
updated: 2026-04-26
---

# SPEC-paywall-rewrite — Paceriz Premium Paywall 重寫

## Background

Paceriz iOS app 即將首次上 App Store。現行 paywall（升級 / Resubscribe / 變更方案 三進場點）有三個結構性問題（詳 TD §0）：

1. **價值不具體**：「升級以解鎖完整功能」是任何 fitness app 的萬用空話，沒有「我為什麼買 Paceriz 而不是別家」的差異化。
2. **AI gating 不透明**：用戶在 onboarding 完成後直到撞牆才第一次認識「核心功能要訂閱」，體感差。
3. **Sheet title 三軌制**：升級／Resubscribe／變更方案 三條路徑顯示三種 navigation title，破壞品牌一致性。

App 尚未在 App Store 上架，是修正訂閱策略最後的免責窗口。本 SPEC 將 Designer 在 TD-paywall-rewrite 提出、產品 owner 已 lock 的決策形式化為可測試 AC，交付給 dev/QA。

同時，Paceriz 後端原本發放的 16 天 backend trial 整批退場，trial 機制收斂為單一來源——Apple Introductory Offer。

## Goals

- 把 paywall sheet navigation title 統一成 `Paceriz Premium`，跨三個進場點一致。
- 重寫 hero copy，依 entry source（default / resubscribe / change_plan）切換 state-aware 文案，去除「unlock potential」這類抽象空話。
- 採 Apple Introductory Offer 30-day Free Trial 作為唯一 trial 來源，僅適用於 Yearly products；Monthly 立即扣款。
- 保留早鳥（Early Bird）方案命名與 RC 後端 gating 邏輯，提供 default + early-bird 兩個 offering，兩者流程一致只差價格。
- 將 backend 16 天 trial 整批退場，新用戶 onboarding 完成後直接是「未訂閱、Free tier」狀態。
- 第一次撞 paywall 走 C2 路線：onboarding 完免費送 Week 1，Week 2 起的「生成週課表 / 週回顧 / 建立目標賽事」三個觸發點各自顯示 inline upsell card；用戶點 CTA 才開 paywall sheet。
- 為每個 paywall entry 帶 `source` parameter，落地 analytics 以利後續轉換率分析。
- 全部新增 i18n key 用 `paywall.premium.*` / `paywall.inline.*` prefix；既有 `paywall.*` key 不修改值。

## Non-Goals

- 不重做 onboarding flow。
- 不改 RevenueCat offering / RC 後端早鳥判定邏輯（除了 ASC 必要的 intro offer 配置）。
- 不改 Rizo 教練（尚未上線，gating 待 Rizo 上線後另外 spec）。
- 不改 race prediction 邏輯，不在本次 gating 範圍。
- 不改 advanced analytics（負荷 / recovery）邏輯，不在本次 gating 範圍。
- 不規劃訂閱後「歡迎頁」展示已解鎖功能（後續 spec）。
- 不規劃跨 app bundle 訂閱、家庭方案、學生方案。
- 不做 trial 7/14/30 天 A/B 測試（依 lock 決策走 30 天，retention 跑 6 個月後再評估）。
- Founder Pricing 重新命名（lock 決策保留 "Early Bird" 命名）。

## User Flows

### Flow 1 — 新用戶首次撞 paywall（Week 2 路徑）

1. 新用戶完成 onboarding + 個人資料 + 連結裝置。
2. App 自動為用戶生成第 1 週週課表（不需訂閱）。
3. 用戶完成 Week 1 訓練，週末打開 app 想看下週課表。
4. App 嘗試生成 Week 2 週課表時偵測到未訂閱 → 顯示 weekly_plan inline upsell card（不直接彈 paywall sheet）。
5. 用戶點 inline card 的「開始 30 天免費試用」CTA。
6. App 開 paywall sheet，title = `Paceriz Premium`，hero 採 default state，source = `weekly_plan_week2`。
7. 用戶選擇 Yearly 卡片，CTA 顯示「開始 30 天免費試用」。
8. 用戶點 CTA → Apple StoreKit 確認 sheet → 確認後開始 trial → sheet dismiss → Week 2 週課表開始生成。

期望結果：用戶不訂閱也能體驗 Week 1；Week 2 起的 paywall 展現「就差這個」的 inline framing；source tracking 寫入 analytics 為 `weekly_plan_week2`。

### Flow 2 — 用戶選 Yearly trial → Apple 確認 → trial 開始

1. 用戶在 paywall sheet 選中 Yearly 卡片（default 或 early-bird）。
2. Sheet 顯示 Trial Timeline（今天 / 第 28 天 / 第 30 天 三步）。
3. CTA 顯示「開始 30 天免費試用」，Disclosure 切到 trial 版（提及 30 天免費 → 自動扣款）。
4. 用戶點 CTA → Apple StoreKit native confirmation sheet 出現。
5. 用戶在 Apple sheet 確認 → 訂閱進入 Apple intro offer trial 狀態。
6. App 收到 transaction → 寫入訂閱狀態 → paywall sheet 自動 dismiss。
7. 之後再開 paywall sheet 會顯示 Trial Banner「你正在試用中，還剩 X 天」。

期望結果：trial 啟動是 Apple StoreKit native 流程，不要自家 backend trial 邏輯；訂閱 entitlement 立即生效。

### Flow 3 — 用戶在 trial 期間打開 paywall sheet

1. 已在 Apple intro offer trial 中的用戶，在 Settings 主動點「升級 / 訂閱管理」打開 paywall sheet。
2. Sheet 顯示 Trial Banner，文案「你正在試用中，還剩 X 天」+「試用結束後將自動扣款，可隨時取消」。
3. Sheet 仍顯示完整內容（features / pricing），但不顯示 Trial Timeline（已在 trial 中）。
4. Source = `settings_upgrade`。

期望結果：trial 中不二次 prompt 試用；提供清楚剩餘天數與扣款預期。

### Flow 4 — 用戶 trial 結束未取消 → 自動扣款 → 解鎖

1. Trial 第 30 天結束，Apple 自動扣款。
2. App 收到 StoreKit transaction → 訂閱狀態從 trial 切到 active。
3. 用戶下次打開 app，paywall sheet 不再彈出；所有 gated 功能可用。

期望結果：扣款由 Apple 自動處理，App 端不需自家 backend trial 邏輯接手。

### Flow 5 — 用戶在 Settings 主動點升級

1. 未訂閱用戶從 Settings 點「升級 / Premium」。
2. 直接開 paywall sheet（不經過 inline card），title = `Paceriz Premium`，hero 採 default state。
3. Source = `settings_upgrade`。

### Flow 6 — 用戶過期 → 重訂

1. 用戶訂閱過期（Apple subscription expired）。
2. 用戶下次打開受限功能（如 Week 2 生成、週回顧、建立目標賽事），App 偵測訂閱已過期。
3. 走 C2 路線：先顯示對應 inline upsell card；用戶點 CTA 開 paywall sheet。
4. Paywall sheet hero 採 resubscribe state：title 仍 = `Paceriz Premium`，hero copy 切到「歡迎回來，繼續完成你的訓練 / 重新訂閱以解鎖完整 AI 功能」。
5. CTA verb 切到「重新訂閱」。
6. Source = `resubscribe`（無論是哪個 inline card 觸發，過期路徑統一以 resubscribe source 上報）。

期望結果：state-aware hero 給用戶情境感的迎回語氣；source 區分新訂 vs 重訂便於 analytics 觀察 churn-back。

### Flow 7 — 用戶切換方案

1. 已訂閱用戶從訂閱管理頁點「變更方案」。
2. 開 paywall sheet，hero 採 change state：title = `Paceriz Premium`，hero copy 切到「變更你的訂閱方案 / 隨時切換月訂與年訂」。
3. CTA verb 切到「變更為此方案」。
4. Source = `change_plan`。
5. 用戶選新卡片 → Apple StoreKit 處理切換 → sheet dismiss。

## Acceptance Criteria

### Sheet 結構與 navigation title

#### AC-PAYWALL-01: Sheet navigation title 統一
**Given** 任何 paywall trigger（升級／Resubscribe／變更方案／三個 inline card 的 CTA／Settings）
**When** 用戶打開 paywall sheet
**Then** Navigation bar title 顯示 `Paceriz Premium`，三語（zh-TW / en-US / ja-JP）皆同此 wording。

#### AC-PAYWALL-02: Sheet 必備 section 順序
**Given** paywall sheet 已開啟
**When** 用戶從上往下檢視
**Then** 元素順序為：Hero → 條件性 Trial Banner（trial state）/ Trial Timeline（focused yearly 時）→ Features 4 groups → Default section → Early-bird section（若 eligible）→ Disclosure → Footer（恢復購買 / 條款 / 隱私）。

#### AC-PAYWALL-03: Sheet 永遠提供「恢復購買」入口
**Given** paywall sheet（任何 entry source）
**When** 用戶捲到底部
**Then** 看到「恢復購買」按鈕，點擊觸發 StoreKit restore 流程。

### Hero copy state-aware

#### AC-PAYWALL-04: Default entry 顯示 default hero
**Given** 用戶為首次訂閱用戶（無過往訂閱紀錄）
**When** 任何 default-class source 觸發 paywall sheet（`weekly_plan_week2` / `weekly_plan_regenerate` / `weekly_review` / `target_race_create` / `settings_upgrade`）
**Then** Hero title 渲染 `paywall.premium.hero.default.title`，subtitle 渲染 `paywall.premium.hero.default.subtitle`。

#### AC-PAYWALL-05: Resubscribe entry 顯示 resubscribe hero
**Given** 用戶過去訂閱過、目前處於 expired 狀態
**When** Source = `resubscribe` 觸發 paywall sheet
**Then** Hero title 渲染 `paywall.premium.hero.resubscribe.title`，subtitle 渲染 `paywall.premium.hero.resubscribe.subtitle`。

#### AC-PAYWALL-06: Change plan entry 顯示 change hero
**Given** 用戶當前訂閱中
**When** Source = `change_plan` 觸發 paywall sheet
**Then** Hero title 渲染 `paywall.premium.hero.change.title`，subtitle 渲染 `paywall.premium.hero.change.subtitle`。

### Trial Timeline 顯示邏輯

#### AC-PAYWALL-07: Trial Timeline 顯示由 Yearly card focus 控制
**Given** 用戶不在 Apple intro offer trial 中（首次訂閱）
**And** Hero 為 default 或 resubscribe 或 change state
**When** Paywall sheet 開啟
**Then** Default Yearly 卡片預設為 focused，Trial Timeline 即時顯示在 Features 區塊上方，三步顯示「今天 / 第 28 天 / 第 30 天」與對應 desc 文案。
**And When** 用戶點選 Early-bird Yearly 卡片
**Then** Trial Timeline 仍顯示（任何 Yearly card focused 即顯示）。

#### AC-PAYWALL-08: Monthly card focused 時不顯示 Trial Timeline
**Given** paywall sheet 已開啟
**When** 用戶點選任一 Monthly 卡片
**Then** Trial Timeline 隱藏（因 Monthly 無 trial、立即扣款）。

#### AC-PAYWALL-09: Trial 中不顯示 Trial Timeline
**Given** 用戶當前處於 Apple intro offer trial 狀態
**When** paywall sheet 開啟
**Then** Trial Timeline 不顯示（已在 trial 中，改顯示 Trial Banner，見 AC-PAYWALL-18）。

### Features comparison table（free vs premium）

> **2026-04-26 更新**：原「4 group features bullets」設計（commit ca9322b）已 supersede 為 comparison table（commit 842c757 設計），於 2026-04-27 還原。理由：comparison table 對 free vs premium 差異一目了然，比文字 bullets 更直接。

#### AC-PAYWALL-10: Features 區塊呈現 free vs premium 比較表
**Given** paywall sheet 已開啟
**When** 用戶捲到 Features 區塊
**Then** 顯示一個 2-column 比較表，左欄為 Free（灰色）、右欄為 Premium（橘色強調），表頭 i18n key = `paywall.comparison.header.free` 與固定字 `Premium`。
**And** 表內 4 列功能項，每列文案來自 i18n key：
  - `paywall.comparison.feature.run_tracking`（free=✓, premium=✓）
  - `paywall.comparison.feature.training_metrics`（free=✓, premium=✓）
  - `paywall.comparison.feature.ai_plan`（free=✗, premium=✓）
  - `paywall.comparison.feature.ai_advice`（free=✗, premium=✓）
**And** 比較表整體有 `accessibilityIdentifier = "Paywall_FeaturesSection"`。

#### AC-PAYWALL-11: 比較表文案直接、不抽象
**Given** Features 比較表
**When** QA review 任何語言版本（zh-TW / en-US / ja-JP）
**Then** 每列功能名稱必須是具體能力（跑步紀錄、訓練指標、AI 課表、AI 建議），不出現「unlock your potential」「升級以解鎖完整功能」等抽象空話。
**And** Free / Premium 列的勾叉必須與實際 gating 邏輯對齊：跑步紀錄 + 訓練指標兩項在無訂閱時可用；AI 課表 + AI 建議需訂閱。

### Default section

#### AC-PAYWALL-12: Default section 永遠顯示
**Given** paywall sheet 已開啟（任何 source、任何用戶）
**When** 用戶捲到 pricing 區
**Then** Default section（Yearly + Monthly 兩張卡）永遠可見。

#### AC-PAYWALL-13: Default Yearly 卡片標示 30 天免費試用
**Given** 用戶非 trial 中
**When** 用戶檢視 Default Yearly 卡片
**Then** 卡片副標渲染 `paywall.premium.plan.trial_format`（代入 30），且 CTA 顯示 `paywall.premium.cta.start_trial`（zh-TW = 「開始 30 天免費試用」）。

#### AC-PAYWALL-14: Default Monthly 卡片標示立即扣款
**Given** paywall sheet 已開啟
**When** 用戶檢視 Default Monthly 卡片
**Then** 卡片副標渲染 `paywall.premium.plan.no_trial_format`（zh-TW = 「立即扣款，無試用期」）；CTA 顯示 `paywall.premium.cta.subscribe_now`。

### Early-bird section

#### AC-PAYWALL-15: Early-bird section 僅於 RC 後端判定 eligible 時顯示
**Given** 用戶 paywall sheet 已開啟
**When** RC 後端 offering metadata 標示用戶 `isEarlyBirdOffering = true`
**Then** Early-bird section 顯示在 Default section 之後；section header 渲染 `paywall.premium.section.earlybird.title`（zh-TW = 「超早鳥方案」、en-US = 「Early Bird」、ja-JP = 「アーリーバード」）。
**And When** `isEarlyBirdOffering = false`
**Then** Early-bird section 完全不渲染。

#### AC-PAYWALL-16: Early-bird Yearly 卡片標示 30 天免費試用
**Given** Early-bird section 顯示
**When** 用戶檢視 Early-bird Yearly 卡片
**Then** 卡片副標渲染 `paywall.premium.plan.trial_format`（代入 30），CTA 顯示 `paywall.premium.cta.start_trial`（早鳥 yearly 同樣享 30 天 trial）。

#### AC-PAYWALL-17: Early-bird Monthly 卡片標示立即扣款
**Given** Early-bird section 顯示
**When** 用戶檢視 Early-bird Monthly 卡片
**Then** 卡片副標渲染 `paywall.premium.plan.no_trial_format`，CTA 顯示 `paywall.premium.cta.subscribe_now`。

### Trial Banner

#### AC-PAYWALL-18: Trial 中 sheet 顯示 Trial Banner
**Given** 用戶處於 Apple intro offer trial 狀態
**When** paywall sheet 開啟（任何 source）
**Then** Hero 下方顯示 Trial Banner，title 渲染 `paywall.premium.trial_banner.format`（代入剩餘天數），subtitle 渲染 `paywall.premium.trial_banner.subtitle`。

#### AC-PAYWALL-19: 非 trial 中 sheet 不顯示 Trial Banner
**Given** 用戶未訂閱、訂閱中、或訂閱過期，但不在 Apple intro offer trial
**When** paywall sheet 開啟
**Then** Trial Banner 不渲染。

### Disclosure trial / 標準版切換

#### AC-PAYWALL-20: 用戶選中 Yearly（trial）卡片 → Disclosure 顯示 trial 版
**Given** paywall sheet 已開啟，用戶非 trial 中
**When** 用戶 focus 任一 Yearly 卡片（含 trial）
**Then** Disclosure 區塊渲染 `paywall.premium.disclosure.trial`（包含 30 天試用、自動續訂、24 小時取消視窗等條款）。

#### AC-PAYWALL-21: 用戶選中 Monthly（無 trial）卡片 → Disclosure 顯示標準版
**Given** paywall sheet 已開啟
**When** 用戶 focus 任一 Monthly 卡片
**Then** Disclosure 區塊渲染 `paywall.premium.disclosure.standard`（即時扣款、自動續訂條款）。

### Inline upsell × 3 顯示與點擊

#### AC-PAYWALL-22: Week 2 生成觸發點顯示 weekly_plan inline card
**Given** 用戶未訂閱、Week 1 已完成
**When** 用戶觸發第 2 週週課表生成（含「重新生成」「調整本週」）
**Then** 顯示 weekly_plan inline upsell card（title 用 `paywall.inline.weekly_plan.title`、body 用 `paywall.inline.weekly_plan.body`、CTA 用 `paywall.inline.cta.start_trial`、副 CTA 用 `paywall.inline.cta.restore`）；不直接開 paywall sheet。
**And When** 用戶點 CTA
**Then** 開 paywall sheet，source = `weekly_plan_week2`（首次 Week 2）或 `weekly_plan_regenerate`（重新生成 / 調整觸發）。

#### AC-PAYWALL-23: 週回顧觸發點顯示 weekly_review inline card
**Given** 用戶未訂閱
**When** 用戶觸發 AI 週回顧
**Then** 顯示 weekly_review inline upsell card（key prefix `paywall.inline.weekly_review.*`）；不直接開 paywall sheet。
**And When** 用戶點 CTA
**Then** 開 paywall sheet，source = `weekly_review`。

#### AC-PAYWALL-24: 建立目標賽事觸發點顯示 target_race inline card
**Given** 用戶未訂閱
**When** 用戶觸發建立目標賽事 / 週訓練目標
**Then** 顯示 target_race inline upsell card（key prefix `paywall.inline.target_race.*`）；不直接開 paywall sheet。
**And When** 用戶點 CTA
**Then** 開 paywall sheet，source = `target_race_create`。

### Gating × 3 行為

#### AC-PAYWALL-25: Week 1 週課表生成不需訂閱
**Given** 新用戶剛完成 onboarding，未訂閱
**When** App 觸發首次週課表生成
**Then** 第 1 週課表正常生成，不觸發任何 paywall / inline card。

#### AC-PAYWALL-26: Week 2+ 週課表 / 重新生成 / 調整需訂閱
**Given** 用戶未訂閱
**When** 用戶觸發第 2 週起任何週課表生成 / 重新生成 / 調整操作
**Then** 顯示 weekly_plan inline upsell card；操作不執行（生成請求不送出）。

#### AC-PAYWALL-27: 訂閱用戶 / trial 中用戶可正常使用三個 gated 功能
**Given** 用戶處於 Apple intro offer trial 中或訂閱 active
**When** 用戶觸發週課表生成（Week 2+）/ 週回顧 / 建立目標賽事
**Then** 三個操作正常執行，不顯示 inline card 也不開 paywall sheet。

### Source tracking

#### AC-PAYWALL-28: Paywall sheet 開啟時必帶 source 與 sub_source
**Given** 任何 paywall sheet 開啟事件
**When** sheet 進入可見狀態
**Then** Analytics 收到 `paywall_opened` 事件，必帶 `source` 與 `sub_source` parameters：
- `source` 值為以下之一：`weekly_plan_week2`、`weekly_plan_regenerate`、`weekly_review`、`target_race_create`、`settings_upgrade`、`resubscribe`、`change_plan`
- `sub_source` 在 `source = resubscribe` 時必填，值為觸發功能：`weekly_plan_week2` / `weekly_plan_regenerate` / `weekly_review` / `target_race_create` / `settings_upgrade` 之一
- 其他 source 時 `sub_source` 為 null

**And** 任何 source 缺失或空值即視為違反 AC。

### Backend trial 退場驗證

#### AC-PAYWALL-29: 新用戶 onboarding 完成後不再進入 backend trial 狀態
**Given** 新用戶完成 onboarding 後
**When** App 讀取訂閱狀態
**Then** 用戶狀態為「未訂閱、Free tier」，不存在 `status=trial_active`（backend 16 天 trial）；唯一 trial 狀態來源為 Apple intro offer。

### i18n keys 完整性

#### AC-PAYWALL-30: 所有新增 key 三語齊備
**Given** 本 SPEC「i18n Keys 完整清單」列舉的所有 `paywall.premium.*` 與 `paywall.inline.*` key
**When** QA 檢查 zh-TW / en-US / ja-JP 三語檔案
**Then** 每個 key 在三語皆有非空值，且不引用尚未存在的格式參數。

### ASC config 驗證（operational AC）

#### AC-PAYWALL-31: ASC 配置 30 天 Free Trial intro offer 涵蓋 default + early-bird yearly
**Given** App Store Connect 訂閱組設定
**When** PM 完成上架前配置
**Then** Default Yearly product 與 Early-bird Yearly product 均掛載 `Free Trial / 30 days / New Subscribers` intro offer，且兩個 product 屬同一 subscription group；Monthly products 不掛載 intro offer。

---

## Pre-Review Hardening（2026-04-27 新增，對應 PLAN-iap-pre-review-hardening.md）

### Disclosure 連結與試用日期揭露（F1 + F2）

#### AC-PAYWALL-32: Disclosure 包含可點擊的隱私政策連結
**Given** 用戶開啟 paywall sheet
**When** 用戶看到 disclosure 區
**Then** 文字內出現可點擊的「隱私政策 / Privacy Policy / プライバシーポリシー」連結；點擊後以 `SFSafariViewController` 開啟既有 Privacy Policy URL；不使用 in-app WebView；不離開 App。

#### AC-PAYWALL-33: Disclosure 包含可點擊的服務條款連結
**Given** 用戶開啟 paywall sheet
**When** 用戶看到 disclosure 區
**Then** 文字內出現可點擊的「服務條款 / Terms of Use / 利用規約」連結；點擊後以 `SFSafariViewController` 開啟既有 Terms of Use URL；不使用 in-app WebView；不離開 App。

#### AC-PAYWALL-34: Yearly card focus 時 disclosure 顯示精確試用結束日期
**Given** 用戶不在 Apple intro offer trial 中（首次訂閱）
**And** 用戶 focus 在 Yearly card（含 default 與 early-bird）
**When** 用戶看到 disclosure 區
**Then** 文字包含「**今天訂閱，試用至 {date}**」之具體結束日期；日期使用 `DateFormatter` 依 user locale 渲染（zh-TW: `2026年5月27日`；en-US: `May 27, 2026`；ja-JP: `2026年5月27日`）；計算邏輯：`now + 30 days`（與 ASC 配置一致）。
**And** Monthly card focus 時 disclosure 不顯示日期（無 trial）。

### Free Tier UI（F4）

#### AC-PAYWALL-35: 未訂閱 + 已生 Week 1 用戶在主頁顯示 Free tier banner
**Given** 用戶 `subscription_status = expired`（未訂閱）
**And** 用戶已生成 Week 1 課表（active_training_id 存在且 week_of_training >= 1）
**When** 用戶開啟主頁（Training Plan V2 主畫面）
**Then** 主頁頂部顯示 Free tier banner，內容包含：
  - 標題：「免費體驗期 / Free Preview / 無料体験中」
  - 副標：「下週課表需訂閱解鎖 / Next week's plan requires subscription / 来週のプランは購読が必要です」
  - CTA：「升級 / Upgrade / アップグレード」
**And** 用戶 `subscription_status ∈ {trial_active, subscribed}`（含 Apple intro trial）→ banner **不顯示**
**And** 用戶尚未生 Week 1（onboarding 後第一次進主頁）→ banner **不顯示**（避免一進來就壓力）
**And** 點擊 banner / CTA → 開啟 paywall sheet，`source=free_tier_banner`，`sub_source=home`

#### AC-PAYWALL-36: 設定頁顯示目前訂閱方案標示
**Given** 用戶開啟設定頁（UserProfileView 或設定主畫面）
**When** 用戶看到 Subscription 區
**Then**：
  - 用戶未訂閱 → 顯示「目前方案：**Free 免費體驗版** / Free Preview / 無料体験版」+ 「升級至完整版 / Upgrade to Premium / プレミアムへアップグレード」CTA
  - 用戶 Apple intro trial 中 → 顯示「目前方案：**試用中（剩 X 天）** / Trial (X days left) / トライアル中（残り{X}日）」
  - 用戶訂閱中 → 顯示「目前方案：**Premium（{方案名}）** / Premium ({plan}) / プレミアム（{プラン}）」+「管理訂閱 / Manage / 管理」CTA（連到 App Store 訂閱管理頁）
**And** Free tier 用戶點擊 CTA → 開啟 paywall sheet，`source=settings_tier`，`sub_source=settings`

#### AC-PAYWALL-37: FreeTierBanner 顯示時 expired dialog 噤聲
**Given** 用戶 `subscription_status = expired`
**And** 用戶**已生 Week 1 課表**（`planOverview != nil`）
**When** App 啟動或前景恢復觸發 `SubscriptionReminderManager.checkAndShowReminder`
**Then** **不**發出 `expired` reminder（因 FreeTierBanner 已在主頁持續顯示，避免重複提醒）
**And** 用戶**未生 Week 1 課表**時，expired dialog 行為不變（每 session 仍會出一次）

理由：兩個 UI 同時顯示「你沒有 premium」訊息對用戶是雜訊，且 banner 已是常駐顯示。

#### AC-PAYWALL-38: Grace period banner 顯示剩餘天數
**Given** 用戶 `inGracePeriod=true` 且有 `graceRemainingDays`
**When** 用戶開啟主頁
**Then** FreeTierBanner 顯示「免費體驗中，剩 X 天」（X = graceRemainingDays），三語齊備
**And** 副標題顯示「7 天後需訂閱解鎖 AI 功能」

#### AC-PAYWALL-39: hasPremiumAccess 在 grace 期內為 true
**Given** 用戶 `status.inGracePeriod=true`
**When** 任何呼叫 `SubscriptionStateManager.shared.hasPremiumAccess`
**Then** 回傳 `true`（解鎖 AI 功能 inline upsell 不觸發）
**And** `hasRealSubscription` 仍為 `false`（區分「真訂閱」vs「grace」）

#### AC-PAYWALL-40: Profile tier label 在 grace 期內顯示剩餘天數
**Given** 用戶 `inGracePeriod=true`
**When** 用戶開設定頁
**Then** tier label 顯示「目前方案：免費體驗中（剩 X 天）」
**And** 顯示「升級至完整版」CTA（讓用戶可主動訂閱）

## i18n Keys 完整清單

> 以下 key 全部新增，既有 `paywall.*` key 不修改值。

### Sheet navigation

| Key | zh-TW | en-US | ja-JP |
|---|---|---|---|
| `paywall.premium.nav_title` | Paceriz Premium | Paceriz Premium | Paceriz Premium |

### Hero（state-aware）

| Key | zh-TW | en-US | ja-JP |
|---|---|---|---|
| `paywall.premium.hero.default.title` | 讓 AI 教練陪你練到下一場 PB | Train smarter with your AI coach | AIコーチと次のPBへ |
| `paywall.premium.hero.default.subtitle` | AI 教練讓你的每一週訓練都對齊目標 | Your AI coach keeps every week aligned with your goals | AIコーチがあなたの毎週のトレーニングを目標に合わせます |
| `paywall.premium.hero.resubscribe.title` | 歡迎回來，繼續完成你的訓練 | Welcome back. Pick up where you left off. | おかえりなさい。トレーニングを続けましょう |
| `paywall.premium.hero.resubscribe.subtitle` | 重新訂閱以解鎖完整 AI 功能 | Resubscribe to unlock all AI features | 再登録してすべてのAI機能を利用 |
| `paywall.premium.hero.change.title` | 變更你的訂閱方案 | Change your plan | プラン変更 |
| `paywall.premium.hero.change.subtitle` | 隨時切換月訂與年訂 | Switch between monthly and annual anytime | 月額・年額の切替はいつでも可能 |

### Trial Timeline（3 step，採 lock 決策的 30 天）

| Key | zh-TW | en-US | ja-JP |
|---|---|---|---|
| `paywall.premium.timeline.step1.label` | 今天 | Today | 今日 |
| `paywall.premium.timeline.step1.desc` | 立即解鎖全部功能 | Unlock everything instantly | 全機能をすぐに利用 |
| `paywall.premium.timeline.step2.label` | 第 28 天 | Day 28 | 28日目 |
| `paywall.premium.timeline.step2.desc` | 我們會提前 2 天提醒你 | We'll remind you 2 days before billing | 課金2日前にお知らせ |
| `paywall.premium.timeline.step3.label` | 第 30 天 | Day 30 | 30日目 |
| `paywall.premium.timeline.step3.desc` | 訂閱開始，可隨時取消 | Subscription starts. Cancel anytime. | サブスク開始（いつでも解約可能） |

### Features（4 groups）

| Key | zh-TW | en-US | ja-JP |
|---|---|---|---|
| `paywall.premium.features.plan.title` | AI 個人化週課表 | AI Personalized Weekly Plan | AIパーソナル週間プラン |
| `paywall.premium.features.plan.bullet1` | 智能週課表，依目標賽事週期化 | Smart weekly plans, periodized for your race | 目標レースに合わせた週期化スマートプラン |
| `paywall.premium.features.plan.bullet2` | 根據體能與恢復狀態自動調整 | Adapts to your readiness and recovery | 体力とリカバリーに応じて自動調整 |
| `paywall.premium.features.plan.bullet3` | 從基礎期到 taper 的完整規劃 | From base to taper, planned for you | ベース期からテーパーまでの完全プラン |
| `paywall.premium.features.adjust.title` | 隨時調整訓練 | Adjust Anytime | いつでも調整 |
| `paywall.premium.features.adjust.bullet1` | 隨時重新生成本週課表 | Regenerate this week's plan anytime | 今週のプランをいつでも再生成 |
| `paywall.premium.features.adjust.bullet2` | 修改單日訓練、AI 自動補回 | Edit a single day, AI rebalances the rest | 1日を編集、AIが残りを再調整 |
| `paywall.premium.features.review.title` | AI 週回顧 | AI Weekly Review | AI週次レビュー |
| `paywall.premium.features.review.bullet1` | 每週訓練表現與負荷自動摘要 | Weekly training and load auto-summary | 週ごとのトレーニングと負荷を自動要約 |
| `paywall.premium.features.review.bullet2` | 下一週訓練重點 AI 建議 | AI suggestions for next week's focus | 来週のフォーカスをAIが提案 |
| `paywall.premium.features.race.title` | 賽事目標規劃 | Race Goal Planning | レース目標プラン |
| `paywall.premium.features.race.bullet1` | 建立目標賽事與週訓練目標 | Set target races and weekly goals | 目標レースと週目標を設定 |
| `paywall.premium.features.race.bullet2` | AI 為你週期化整個訓練計畫 | AI periodizes your entire training plan | AIがトレーニング全体を週期化 |

### Pricing section labels

| Key | zh-TW | en-US | ja-JP |
|---|---|---|---|
| `paywall.premium.section.default.title` | 標準方案 | Standard Plans | スタンダードプラン |
| `paywall.premium.section.default.subtitle` | 30 天免費試用，隨時取消 | 30-day free trial. Cancel anytime. | 30日間無料体験。いつでも解約可能 |
| `paywall.premium.section.earlybird.title` | 超早鳥方案 | Early Bird | アーリーバード |
| `paywall.premium.section.earlybird.subtitle` | 上架前優惠價，享 30 天免費試用 | Pre-launch pricing with 30-day free trial | 上場前価格、30日間無料体験付き |

### Plan card labels

| Key | zh-TW | en-US | ja-JP |
|---|---|---|---|
| `paywall.premium.plan.annual.label` | 年訂 | Annual | 年額 |
| `paywall.premium.plan.annual.badge_recommended` | 推薦 | RECOMMENDED | おすすめ |
| `paywall.premium.plan.annual.savings_format` | 年訂省 %@%% | Save %@%% with annual | 年額で%@%%お得 |
| `paywall.premium.plan.monthly.label` | 月訂 | Monthly | 月額 |
| `paywall.premium.plan.trial_format` | %@ 天免費試用後扣款 | %@ days free, then charged | %@日間無料、その後課金 |
| `paywall.premium.plan.no_trial_format` | 立即扣款，無試用期 | Charged immediately, no trial | 即時課金、トライアルなし |

### CTA buttons

| Key | zh-TW | en-US | ja-JP |
|---|---|---|---|
| `paywall.premium.cta.start_trial` | 開始 30 天免費試用 | Start 30-day free trial | 30日間の無料体験を開始 |
| `paywall.premium.cta.subscribe_now` | 立即訂閱 | Subscribe now | 今すぐ登録 |
| `paywall.premium.cta.resubscribe` | 重新訂閱 | Resubscribe | 再登録 |
| `paywall.premium.cta.change_plan` | 變更為此方案 | Switch to this plan | このプランに変更 |

### Trial Banner（trial 中顯示）

| Key | zh-TW | en-US | ja-JP |
|---|---|---|---|
| `paywall.premium.trial_banner.format` | 你正在試用中，還剩 %@ 天 | You're on trial — %@ days left | トライアル中 — 残り%@日 |
| `paywall.premium.trial_banner.subtitle` | 試用結束後將自動扣款，可隨時取消 | Auto-renews after trial. Cancel anytime. | トライアル後自動更新。いつでも解約可能 |

### Disclosure（trial 版 + 標準版）

| Key | zh-TW |
|---|---|
| `paywall.premium.disclosure.trial` | 點擊「開始 30 天免費試用」即代表你同意：免費試用期為 30 天，到期後將以所選方案價格自動續訂並從你的 Apple ID 扣款。試用期結束 24 小時前可在 Apple ID 設定中取消，避免扣款。訂閱會在每個週期結束前 24 小時自動續訂，除非你取消。詳情請參閱 [使用條款] 與 [隱私權政策]。 |
| `paywall.premium.disclosure.standard` | 點擊「立即訂閱」即代表你同意：將立即從你的 Apple ID 扣款並訂閱所選方案。訂閱會在每個週期結束前 24 小時自動續訂，除非你在當前週期結束 24 小時前於 Apple ID 設定中取消。詳情請參閱 [使用條款] 與 [隱私權政策]。 |

| Key | en-US |
|---|---|
| `paywall.premium.disclosure.trial` | By tapping "Start 30-day free trial" you agree: your free trial lasts 30 days, after which your selected plan will auto-renew at the listed price billed to your Apple ID. Cancel at least 24 hours before the trial ends in your Apple ID settings to avoid charges. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. See [Terms of Use] and [Privacy Policy]. |
| `paywall.premium.disclosure.standard` | By tapping "Subscribe now" you agree: your selected plan will be billed immediately to your Apple ID. Subscriptions auto-renew at the same price unless cancelled at least 24 hours before the end of the current period in your Apple ID settings. See [Terms of Use] and [Privacy Policy]. |

| Key | ja-JP |
|---|---|
| `paywall.premium.disclosure.trial` | 「30日間の無料体験を開始」をタップすることで、以下に同意したものとみなされます：無料体験期間は30日間です。期間終了後、選択したプランは自動的に更新され、Apple IDに記載の価格で課金されます。課金を回避するには、トライアル終了の24時間前までにApple IDの設定からキャンセルしてください。各更新期間終了の24時間前までに解約しない限り、サブスクリプションは自動更新されます。詳細は[利用規約]と[プライバシーポリシー]をご覧ください。 |
| `paywall.premium.disclosure.standard` | 「今すぐ登録」をタップすることで、以下に同意したものとみなされます：選択したプランはApple IDから即時に課金されます。各更新期間終了の24時間前までにApple IDの設定で解約しない限り、サブスクリプションは同じ価格で自動更新されます。詳細は[利用規約]と[プライバシーポリシー]をご覧ください。 |

### Inline upsell cards（× 3）

| Key | zh-TW | en-US | ja-JP |
|---|---|---|---|
| `paywall.inline.weekly_plan.title` | 解鎖完整週課表 | Unlock your full weekly plan | 週間プランを全て解放 |
| `paywall.inline.weekly_plan.body` | Week 1 是免費的。訂閱後可生成第 2 週起的個人化課表，並可隨時重新調整 | Week 1 is free. Subscribe to generate Week 2+ and re-adjust anytime | 第1週は無料。サブスク登録で第2週以降の生成と再調整が可能 |
| `paywall.inline.weekly_review.title` | AI 週回顧是 Premium 功能 | Weekly Review is a Premium feature | 週次レビューはPremium機能 |
| `paywall.inline.weekly_review.body` | 由 AI 整理你本週的訓練表現、負荷與下週建議 | Get an AI-curated summary of your week's training, load, and next-week tips | 今週のトレーニングと負荷をAIが整理、来週の提案も |
| `paywall.inline.target_race.title` | 設定目標賽事是 Premium 功能 | Setting a target race is a Premium feature | 目標レース設定はPremium機能 |
| `paywall.inline.target_race.body` | 訂閱後可建立目標賽事與週訓練目標，由 AI 為你週期化規劃 | Subscribe to set target races and weekly goals, with AI race-periodized planning | サブスク登録で目標レースと週目標を設定、AIが週期化プランを作成 |
| `paywall.inline.cta.start_trial` | 開始 30 天免費試用 | Start 30-day free trial | 30日間の無料体験を開始 |
| `paywall.inline.cta.restore` | 已訂閱？恢復購買 | Already subscribed? Restore | 登録済み？復元する |

## ASC Config 需求（PM action item）

PM 在 ASC 完成以下配置作為上架前 prerequisite：

- 在訂閱組（subscription group）中確認 default Yearly product（如 `paceriz.sub.yearly`）與 early-bird Yearly product 屬於同一 group。
- 為 default Yearly product 掛載 Introductory Offer：類型 `Free Trial`、長度 `30 days`、適用對象 `New Subscribers`。
- 為 early-bird Yearly product 掛載 Introductory Offer：類型 `Free Trial`、長度 `30 days`、適用對象 `New Subscribers`。
- Default Monthly product 不掛載任何 introductory offer。
- Early-bird Monthly product 不掛載任何 introductory offer。
- 配置完成後，PM 通知 dev 進行 sandbox 測試。

## Out of Scope / Future

- Rizo AI 教練 gating（待 Rizo 上線後另開 spec，本 SPEC 不規範）。
- Race prediction gating（lock 決策不 gate）。
- Advanced analytics（負荷 / recovery）gating（lock 決策不 gate）。
- 訂閱後的「歡迎頁」展示已解鎖功能（後續 spec）。
- 跨 app bundle 訂閱（如 Paceriz + 跑鞋商 / 賽事報名平台）。
- 家庭方案、學生方案。
- A/B test trial 7 / 14 / 30 天（trial 跑滿 6 個月、retention 數據 ready 後再評估）。
- Founder Pricing 重命名（lock 決策保留 "Early Bird"）。
- Trial 「48 小時內必須建 plan 否則 trial 失效」這類 dark pattern。

## Open Questions

- **OQ-1 — RESOLVED**: 預設 focus default Yearly card。已合併入 AC-PAYWALL-07。
- **OQ-2 — RESOLVED**: Resubscribe source 加 `sub_source` 欄位記錄觸發功能。已合併入 AC-PAYWALL-28。
- **OQ-3 — N/A**: App 未上線、無存量用戶。原 AC-PAYWALL-30（存量 backend trial 用戶收斂）已 drop。
- **OQ-4 — DEFERRED**: 早鳥 Monthly 是否簡化留給行銷後續評估，本 SPEC 不變更。
