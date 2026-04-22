---
spec: SPEC-target-race-edit-selection.md
td: TD-target-race-edit-selection.md
plan_id: 7bb49db362bf44b6b660b0b36b5dabfd
parent_task: 45e9d9b517ac452493508a501e9e9a16
created: 2026-04-22
updated: 2026-04-22
status: in-progress
entry_criteria: TD approved by user (Option A + D3 auto-clear confirmed 2026-04-22)
exit_criteria: 所有 P0 AC test 從 FAIL 變 PASS + onboarding race-selection Maestro 不退步 + QA Verdict PASS
---

# PLAN: 目標賽事編輯支援賽事資料庫選擇

## Tasks

- [ ] **S01**: Target.swift 加 `raceId: String?` + CodingKey + `decodeIfPresent`
  - Files: `Havital/Models/Target.swift`
  - Verify: clean build pass；既有 onboarding smoke 不 crash

- [ ] **S02**: 定義 `RacePickerDataSource` protocol；`RaceEventListView` 泛化；`OnboardingFeatureViewModel` extension 聲明 conformance；移除 `OnboardingCoordinator.shared.goBack()` 改用 `@Environment(\.dismiss)`
  - Files:
    - `Havital/Features/Race/Domain/Repositories/RacePickerDataSource.swift` (new)
    - `Havital/Views/Onboarding/RaceEventListView.swift` (modify)
    - `Havital/Features/Onboarding/Presentation/ViewModels/OnboardingFeatureViewModel.swift` (extension append)
    - `Havital/Views/Onboarding/OnboardingContainerView.swift:87` (pass `dataSource: viewModel`)
  - Verify: clean build pass；`.maestro/flows/onboarding-race-event-selection.yaml` + `onboarding-race-event-search.yaml` 跑過不退步
  - depends: S01

- [ ] **S03**: 新增 `TargetEditRacePickerViewModel`（conform `RacePickerDataSource`）
  - Files: `Havital/Features/Target/Presentation/ViewModels/TargetEditRacePickerViewModel.swift` (new)
  - Verify: Unit test AC-TREDIT-02/03 PASS
  - depends: S02

- [ ] **S04**: `EditTargetViewModel` 改造 — 加 raceId 欄位、`applyRaceSelection`/`clearRaceSelection`、`updateTarget()` 帶入 raceId、raceName/distance 的 `willSet` 觸發 auto-clear（D3）
  - Files: `Havital/Views/EditView/EditTargetView.swift:110-279` (EditTargetViewModel 區塊)
  - Verify: Unit test AC-TREDIT-04/05 PASS
  - depends: S01

- [ ] **S05**: `BaseSupportingTargetViewModel` 對稱改造
  - Files: `Havital/Features/Target/Presentation/ViewModels/BaseSupportingTargetViewModel.swift`
  - Verify: Unit test supporting 版 AC-TREDIT-04/05 PASS
  - depends: S01

- [ ] **S06**: 加「從資料庫選擇」UI 入口
  - Files:
    - `Havital/Views/EditView/EditTargetView.swift` (加新 Section + NavigationLink/Sheet wiring 到 RaceEventListView)
    - `Havital/Views/EditView/EditSupportingTargetView.swift` (同上)
    - `Havital/Views/EditView/AddSupportingTargetView.swift` (同上)
  - Verify: clean build pass；手動 simulator 進編輯畫面看到雙入口
  - depends: S03, S04, S05

- [ ] **S07**: 填完 Maestro flow stubs（5 條）
  - Files: `.maestro/flows/spec-compliance/target-race-edit/AC-TREDIT-*.yaml`
  - Verify: 所有 flow 在 iPhone 17 Pro (UDID 237D67B5-E7D0-4057-A8A1-F4FEDBC6875D) PASS
  - depends: S06

- [ ] **S08**: QA 驗收
  - Verify: QA Verdict PASS（含所有 AC test + onboarding 回歸 + 靜態檢查 + simulator 端到端）
  - depends: S07

## Decisions

- **2026-04-22 D1**: race picker 優先重用，不複製。來源：用戶明確要求 UX 一致性。
- **2026-04-22 D2**: 採用 Option A（協議解耦）。理由：`OnboardingCoordinator.goBack()` 本質是 `navigationPath.removeLast()`，與 `@Environment(\.dismiss)` 在 `NavigationStack(path: $binding)` 架構下等效；`OnboardingContainerView.destinationView` 只需 1 行改動（`RaceEventListView()` → `RaceEventListView(dataSource: viewModel)`）；無 onboarding regression 風險。
- **2026-04-22 D3**: AC-TREDIT-05 清除 race_id 的觸發時機 = 用戶手動編輯 raceName 或 distance 欄位時自動清除（非儲存時比對）。理由：UX 更直覺，編輯即脫離資料庫綁定。

## Dispatch Strategy

單一 Developer dispatch 覆蓋 S01–S07（iOS 改動緊密耦合，一次 implementation pass 並逐 AC test 補完比分批更有效率）。
完成後獨立 QA dispatch（S08）。

## Resume Point

**當前狀態**：TD 完成，AC test stubs 就位（XCTest 7 個 + Maestro 5 條），PLAN 建立完成。
**下一步**：Dispatch Developer 執行 S01–S07。Task ID `45e9d9b517ac452493508a501e9e9a16` handoff to agent:developer。
