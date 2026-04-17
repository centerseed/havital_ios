---
type: REF
id: REF-app-spec-coverage-map
status: Draft
ontology_entity: app-spec-governance
created: 2026-04-15
updated: 2026-04-15
---

# App Spec Coverage Map

## Canonical 路徑

- `Docs/specs/`：產品規格
- `Docs/designs/`：技術設計
- `Docs/decisions/`：架構決策
- `Docs/tests/`：驗收場景
- `Docs/reference/`：索引、背景知識、治理參考

## Coverage Matrix

| 區塊 | Canonical Spec | 狀態 | 備註 |
|------|----------------|------|------|
| Authentication / Session Entry | `Docs/specs/SPEC-authentication-and-session-entry.md` | Draft | 補齊 app 入口與 session 路由 |
| App Shell / Global Guardrail | `Docs/specs/SPEC-app-shell-routing-and-global-guardrails.md` | Draft | 新增，補全域路由與警示行為 |
| Onboarding Shell | `Docs/specs/SPEC-onboarding-redesign.md` | Approved | 現有總體 onboarding spec |
| Onboarding Race Selection | `Docs/specs/SPEC-onboarding-race-selection.md` | Draft | 從獨立 draft 收斂為子規格 |
| Subscription / IAP Pricing | `Docs/specs/SPEC-iap-paywall-pricing-and-trial-protection.md` | Draft | 現有 |
| Subscription Management | `Docs/specs/SPEC-subscription-management-and-status-ui.md` | Draft | 現有 |
| Analytics P0 | `Docs/specs/SPEC-ios-analytics-p0.md` | Draft | AC-ID 化程度最高 |
| Training Hub | `Docs/specs/SPEC-training-hub-and-weekly-plan-lifecycle.md` | Draft | 補首頁狀態機與操作入口 |
| Weekly Preview UI | `Docs/specs/SPEC-weekly-preview-ui.md` | Under Review | 現有子規格 |
| Training V2 Edit Schedule | `Docs/specs/SPEC-training-v2-edit-schedule-screen.md` | Draft | 現有子規格 |
| Training Record | `Docs/specs/SPEC-training-record-and-workout-detail.md` | Draft | 現有 |
| Workout Post Actions / Share Card | `Docs/specs/SPEC-workout-post-actions-and-share-card.md` | Draft | 新增，補心得、重傳、刪除與分享 |
| Profile / Integration Management | `Docs/specs/SPEC-profile-and-data-integration-management.md` | Draft | 現有 |
| Settings / Feedback | `Docs/specs/SPEC-settings-and-feedback-management.md` | Draft | 新增，補語言、時區、feedback |
| Performance Dashboard | `Docs/specs/SPEC-performance-insights-dashboard.md` | Draft | 現有 |
| Heart Rate / Training Readiness | `Docs/specs/SPEC-heart-rate-and-training-readiness-surfaces.md` | Draft | 新增，補心率設定與 readiness surface |
| Target Lifecycle | `Docs/specs/SPEC-target-lifecycle-and-supporting-races.md` | Draft | 現有，補 main/supporting target 管理 |
| Data Backfill / Calendar Sync | `Docs/specs/SPEC-data-backfill-and-calendar-sync.md` | Draft | 現有，補歷史資料同步與日曆同步 |
| Monthly Stats / Calendar Surface | `Docs/specs/SPEC-monthly-stats-and-calendar-performance-surfaces.md` | Draft | 現有，補 monthly stats 與月曆整合 |
| TrainingPlan V1 Legacy Boundary | `Docs/specs/SPEC-training-plan-v1-legacy-boundary.md` | Draft | 現有，明確 V1 維護邊界 |
| Dual-Track Cache Strategy | `Docs/specs/SPEC-dual-track-cache-and-background-refresh.md` | Draft | 現有，抽出跨模組快取策略 |
| Maestro UI Guardrail | `Docs/specs/SPEC-maestro-ui-final-guardrail.md` | Approved | 測試防線，不是產品主流程 spec |

## Design / Decision 對應

| 類型 | Canonical File |
|------|----------------|
| Onboarding Design | `Docs/designs/TD-onboarding-redesign.md` |
| iOS Analytics Design | `Docs/designs/TD-ios-analytics-p0.md` |
| Training V2 Edit Strength Design | `Docs/designs/TD-training-v2-edit-strength.md` |
| Subscription Decisions | `Docs/decisions/ADR-001` ~ `ADR-004` |
| Dual-Track Cache Test | `Docs/tests/TEST-dual-track-cache-and-background-refresh.md` |
| Cache TTL / Boundary Reference | `Docs/reference/REF-cache-ttl-and-user-boundary-matrix.md` |
| Internal Debug / Admin Reference | `Docs/reference/REF-internal-debug-and-admin-surfaces.md` |

## 本次整理結果

1. `TD-onboarding-redesign` 已從 spec 區歸位到 `Docs/designs/`
2. Onboarding race selection 已獨立為 canonical 子規格，避免和總體 onboarding spec 混成同一份
3. 核心缺口已補上：auth/session、app shell、training hub、training record、workout post actions、profile、settings、performance、heart rate / readiness
4. 架構層行為已補文件化：target lifecycle、data sync、monthly stats surface、V1 legacy boundary、dual-track cache
5. 舊 FRD / refactor / migration 類文件已移往 archive，只保留 canonical 路徑作為 SSOT
6. Cache TTL / user boundary 與 internal debug/admin surfaces 已補成 reference，不再算主目錄 gap
7. `onboarding / training hub / profile / data sync / subscription` 已補正式 AC-ID index，可直接被 task / QA 引用
8. `iap / performance / training record / target / monthly stats / V1 legacy boundary` 也已補正式 AC-ID index，主要 spec 已具備穩定引用能力

## Remaining Gaps

目前主要產品 spec 已完成 AC-ID 正規化。剩餘治理工作不在「spec 引用格式」而在：

- 若要進一步提升可派工性，可把部分 spec 的 AC-ID 從索引式提升為逐條 section-level traceability matrix。
- 若要進一步提升驗收閉環，可補更多對應 TEST 文件，而不是再補 spec 結構。
