---
spec: SPEC-paywall-rewrite.md
related_design: TD-paywall-rewrite.md
ac_stubs: HavitalTests/spec_compliance/PaywallACTests.swift
created: 2026-04-26
status: in-progress
entry_criteria: SPEC + TD + AC stubs ready
exit_criteria: 31/31 AC tests PASS + simulator screenshot verification + Architect AC sign-off
---

# PLAN: Paceriz Premium Paywall 重寫

## Tasks

### Phase D1 — UI / Visual Layer

- [ ] **S01**: i18n keys + Sheet nav title
  - Files:
    - `Havital/Resources/zh-Hant.lproj/Localizable.strings` (add ~40 new keys)
    - `Havital/Resources/en.lproj/Localizable.strings` (same)
    - `Havital/Resources/ja.lproj/Localizable.strings` (same)
    - `Havital/Features/Subscription/Presentation/Views/PaywallView.swift` (.navigationTitle)
  - Covers AC: **01, 30**
  - Verify: `grep "paywall.premium" 三個 .strings` 應該都有對應 key

- [ ] **S02**: Hero state-aware (default / resubscribe / change)
  - Files: `PaywallView.swift` (heroSection)
  - 移除現有 trophy 已移除後的 fallback hero text
  - 依 trigger 切換三套 hero copy
  - Covers AC: **04, 05, 06**

- [ ] **S03**: Features 4 groups
  - Files: `PaywallView.swift` (featuresSection)
  - 把現有 3 條 flat list 改成 4 個 group（plan / adjust / review / race）
  - 每個 group title + bullets
  - 不出現 Rizo / race prediction / advanced analytics
  - Covers AC: **10, 11**

- [ ] **S04**: Trial Timeline UI + Trial Banner
  - Files (new):
    - `Havital/Features/Subscription/Presentation/Components/PaywallTrialTimelineView.swift`
    - `Havital/Features/Subscription/Presentation/Components/PaywallTrialBanner.swift`
  - Files (modify): `PaywallView.swift`
  - Trial Timeline：3 步水平佈局，今天 / 第 28 天 / 第 30 天
  - 顯示條件：非 trial 中 + 任一 Yearly card focused（預設 default Yearly）
  - Trial Banner：trial 中時顯示，含剩餘天數
  - Covers AC: **07, 08, 09, 18, 19**

- [ ] **S05**: Default + Early-bird sections + Disclosure switch
  - Files: `PaywallView.swift` (defaultSection / earlyBirdSection / disclosure)
  - Default section：永遠顯示，Yearly 標 30 天 trial / Monthly 立即扣款
  - Early-bird section：僅 isEarlyBirdOffering 顯示，Yearly 也標 30 天 trial / Monthly 立即扣款
  - Disclosure：依用戶 focus 的卡片切換 trial / standard 版
  - Sheet 結構順序：Hero → Banner/Timeline → Features → Default → Early-bird → Disclosure → Footer
  - Covers AC: **02, 03, 12, 13, 14, 15, 16, 17, 20, 21**

### Phase D2 — Logic / Integration Layer

- [ ] **S06**: Inline upsell cards × 3
  - Files (new):
    - `Havital/Features/Subscription/Presentation/Components/WeeklyPlanInlineUpsellCard.swift`
    - `Havital/Features/Subscription/Presentation/Components/WeeklyReviewInlineUpsellCard.swift`
    - `Havital/Features/Subscription/Presentation/Components/TargetRaceInlineUpsellCard.swift`
  - 統一 layout：title + body + primary CTA「開始 30 天免費試用」 + 副 CTA「已訂閱？恢復購買」
  - 點 CTA 開 paywall sheet 並帶對應 source
  - Covers AC: **22, 23, 24**

- [ ] **S07**: Gating at 3 entry points
  - Files (modify):
    - 週課表 ViewModel（Developer 自行定位，建議 grep "weekly plan generate" / "regenerate"）
    - 週回顧 ViewModel（grep "weekly review"）
    - 賽事目標 ViewModel（grep "target race" / "race goal"）
  - 邏輯：未訂閱 + 非 trial → 觸發時顯示對應 inline card 取代原本的執行
  - Week 1 例外：首次週課表生成不擋
  - 訂閱中 / trial 中：照常執行
  - Covers AC: **25, 26, 27**

- [ ] **S08**: Source tracking + Backend trial iOS retirement
  - Files:
    - `Havital/Core/Analytics/AnalyticsEvent.swift`（新增 paywall_opened with source/sub_source）
    - `Havital/Features/Subscription/Domain/Managers/SubscriptionStateManager.swift`（移除 / 忽略 backend trial 邏輯）
  - 7 種 source 列舉成 enum
  - resubscribe 時必帶 sub_source
  - 新用戶不再走 backend 16 天 trial（iOS 端不訂閱該 state）
  - Covers AC: **28, 29**

### Phase Op — Operational

- [ ] **S09 (User/PM)**: ASC config 30-day Free Trial
  - 在 App Store Connect：
    - default Yearly product → Free Trial / 30 days / New Subscribers
    - early-bird Yearly product → Free Trial / 30 days / New Subscribers
    - 確認兩者同一 subscription group
    - Monthly products 不掛 intro offer
  - **此 task 用戶 own**，與 D1/D2 並行不阻塞
  - Covers AC: **31**

## Decisions

- **2026-04-26**: Trial 30 天（Strava 模式，A1 = 只 Yearly trial）
- **2026-04-26**: 早鳥同 trial 同流程，只差價（不改 Founder Pricing 命名）
- **2026-04-26**: Backend 16 天 trial 退場（B1，app 未上線無遷移成本）
- **2026-04-26**: 第一次撞 paywall = Week 2 路徑（C2，Week 1 免費送）
- **2026-04-26**: Sheet nav title 統一「Paceriz Premium」
- **2026-04-26**: Gating 縮小到訓練閉環 3 點（生成週課表 Week 2+ / 週回顧 / 建立目標）
- **2026-04-26**: Features 4 groups 重寫，禁止宣稱 Rizo / race prediction / advanced analytics
- **2026-04-26**: Inline upsell 先於 paywall sheet（C2 路線完整度）
- **2026-04-26**: Source tracking 加 sub_source（resolve OQ-2）

## Resume Point

Architect 已完成：SPEC + TD + AC stubs + PLAN。
**下一步**：dispatch Developer for Phase D1（S01-S05），完工後 Architect 審查 → dispatch QA → Architect AC sign-off → Phase D2 → 同流程 → 終局 sign-off。

## Dispatch Plan

| Phase | Tasks | Dispatch | Expected duration |
|---|---|---|---|
| D1 | S01-S05 (UI/Visual) | Developer agent (single dispatch) | 1 day |
| QA-1 | Verify D1 ACs | QA agent | 0.5 day |
| D2 | S06-S08 (Logic/Integration) | Developer agent (single dispatch) | 1 day |
| QA-2 | Verify D2 ACs | QA agent | 0.5 day |
| Sign-off | Architect 31 AC sign-off + simulator screenshot | Architect | 0.5 day |
| Op | ASC config | User parallel | (any time) |

## Dispatch Status

- D1: not started
- D2: not started
- ASC config: not started
