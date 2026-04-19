---
spec: SPEC-weekly-adjustment-selection.md
design: TD-weekly-adjustment-selection.md
created: 2026-04-18
status: done
---

# PLAN: 週回顧調整建議接受／拒絕

## Entry Criteria
- [x] SPEC 完成（AC-WKADJ-01 ~ AC-WKADJ-10）
- [x] 後端 API 合約確認（POST /v2/summary/weekly/apply-items）
- [x] TD 完成（TD-weekly-adjustment-selection.md）
- [x] AC test stubs 建立（HavitalTests/TrainingPlan/Spec/WeeklyAdjustmentSelectionACTests.swift）

## Tasks

- [x] S01: Data Layer — DTO + DataSource + Repository
- [x] S02: Coordinator — Toggle State + Apply Method
- [x] S03: View Layer — Toggle UI + 按鈕文字 + Impact + Header 計數
- [x] S04: Wiring — TrainingPlanV2View onGenerateNextWeek
- [x] QA: 驗收所有 10 條 AC（10/10 PASS，2026-04-18）
- [x] Fix: Maestro weekly-summary-generate.yaml assertion 更新為新按鈕文字

## Exit Criteria
- [ ] 所有 AC test stubs（AC-WKADJ-01 ~ 10）PASS
- [ ] Clean build 零錯誤
- [ ] QA verdict: PASS
- [ ] `/simplify` 已執行

## Decisions
- 2026-04-18: apply-items 失敗時中止課表生成（不 silent fail），保護 AC-WKADJ-03 語意
- 2026-04-18: P2（AC-WKADJ-10 還原預設）包含在本次實作，因為 S02 代價極低
- 2026-04-18: `use_coordinator` 固定不傳（預設 false），MVP 不需 LLM 衝突解析

## Resume Point
已完成。QA Verdict PASS（2026-04-18）。
