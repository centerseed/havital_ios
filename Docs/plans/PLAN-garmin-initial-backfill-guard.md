---
spec: SPEC-garmin-initial-backfill-guard.md
created: 2026-05-01
status: in-progress
entry_criteria: SPEC-garmin-initial-backfill-guard has AC IDs and TD/TEST are ready
exit_criteria: AC-GARMIN-BF-01 through AC-GARMIN-BF-12 pass in backend/iOS targeted tests and QA Verdict is PASS
---

# PLAN: Garmin Initial Backfill Guard

## Tasks

- [ ] S01: Backend coverage guard, ensure-initial endpoint, structured logs
  - Files: `/Users/wubaizong/havital/cloud/api_service/api/v1/garmin_backfill.py`, `/Users/wubaizong/havital/cloud/api_service/domains/integrations/connect/garmin_backfill_service.py`, `/Users/wubaizong/havital/cloud/api_service/core/database/repositories/garmin_backfill_repository.py`, backend tests
  - Verify: `.venv/bin/pytest tests/spec_compliance/test_garmin_initial_backfill_guard_ac.py -q`
- [ ] S02: iOS callback calls ensure-initial instead of raw backfill
  - Files: `Havital/Core/Infrastructure/GarminManager.swift`, `Havital/Features/Workout/Infrastructure/BackfillService.swift`, `HavitalTests/...`
  - Verify: `xcodebuild test ... -only-testing:HavitalTests/GarminInitialBackfillGuardACTests`
- [ ] S03: QA acceptance
  - Files: `docs/tests/TEST-garmin-initial-backfill-guard.md`
  - Verify: backend/iOS targeted tests + grep evidence

## Decisions

- 2026-05-01: 「首次 backfill」由後端 durable coverage 判斷，不由 iOS OAuth callback 或 UserDefaults 判斷。
- 2026-05-01: 首次自動 backfill 保留，但 App 只呼叫 `ensure-initial` guard endpoint。

## Resume Point

文件包已建立。下一步：dispatch S01 給 backend Developer、S02 給 iOS Developer。
