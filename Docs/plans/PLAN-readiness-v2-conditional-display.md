---
spec: docs/specs/SPEC-readiness-v2-conditional-display.md
td: docs/designs/TD-readiness-v2-conditional-display.md
created: 2026-04-28
status: done
---

# PLAN: Readiness V2 — 依 plan_type 條件顯示

## Entry Criteria
- Handoff 文件 `cloud/api_service/docs/handoffs/HANDOFF-readiness-v2-ios-conditional-display.md` 已讀
- SPEC + TD + AC test stubs 已產出（✅ done）
- Backend `plan_type` 欄位尚未 deploy（iOS 先用 mock data / dev backend 驗）

## Exit Criteria
- AC-RDNS-01 ~ AC-RDNS-05 全 PASS
- clean build 零錯誤
- 三種 plan_type simulator 截圖各一（QA 驗收）

## Tasks

- [x] S01: Data + Domain 層改動（planType 欄位 + ReadinessPlanType enum）
  - Files: `Havital/Models/TrainingReadinessModels.swift`
  - Verify: `test_ac_rdns_01/02/03` model 部分 PASS ✅
- [x] S02: ViewModel fallback logic（effectivePlanType + planOverviewProvider）
  - Files: `Havital/Features/TrainingPlan/Presentation/ViewModels/TrainingReadinessViewModel.swift`
  - Verify: `test_ac_rdns_04`, `test_ac_rdns_04_both_nil_defaults_to_show_all` PASS ✅
- [x] S03: View 條件渲染（radar / score / race time / status_text + metricsGrid guard）
  - Files: `Havital/Views/Components/TrainingReadinessView.swift`
  - Verify: QA 截圖 race_run PASS；beginner/maintenance 視覺留待 backend V2 deploy 後補 ✅
- [x] S04: Cache invalidation（overviewDidUpdate → forceRefresh）
  - Files: `Havital/Features/TrainingPlan/Domain/UseCases/TrainingReadinessManager.swift`
  - Verify: `test_ac_rdns_05` PASS ✅
- [x] S05: QA 整合驗收 — PASS（race_run 視覺 + 6/6 AC tests）✅

## Decisions

- 2026-04-28: `overviewDidUpdate` publisher 取代 CacheEventBus，因為更精準不需走事件分類
- 2026-04-28: `.unknown` fallback → 預設 race_run 全套（保守不隱藏）
- 2026-04-28: `overall_status_text` 對 beginner/maintenance 隱藏（用戶確認）

## Resume Point

完成。Backend V2 readiness deploy 後，補做 beginner/maintenance 視覺 smoke test。
