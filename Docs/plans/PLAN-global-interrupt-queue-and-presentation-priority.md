---
spec: SPEC-global-interrupt-queue-and-presentation-priority.md
created: 2026-04-23
updated: 2026-04-24
status: done
plan_id: b74e01ea228a49b2b96e1eda5a7c6260
---

# PLAN: Global Interrupt Queue And Presentation Priority

## Tasks
- [x] S01: 實作 interrupt core 與 root host
  - Files: `Havital/Core/Presentation/Interrupts/*`, `Havital/Views/ContentView.swift`
  - Verify: `HavitalTests/SpecCompliance/GlobalInterruptQueueACTests.swift`
  - ZenOS: `55738f0b4bf448d69d0600cc952cd190` → done (2026-04-23)
- [x] S02: 遷移 data-source reminder / announcement / paywall 三條 presenter 熱點
  - Files: `Havital/Core/Presentation/ViewModels/AppViewModel.swift`, `Havital/Features/Announcement/Presentation/ViewModels/AnnouncementViewModel.swift`, `Havital/Features/TrainingPlanV2/Presentation/Views/TrainingPlanV2View.swift`, `Havital/Views/UserProfileView.swift`
  - Verify: `HavitalTests/SpecCompliance/GlobalInterruptQueueACTests.swift` + Maestro regression
  - ZenOS: `55738f0b4bf448d69d0600cc952cd190` (combined with S01)
- [x] S03: QA 驗收全域 interrupt queue
  - Files: `.maestro/flows/*`, `HavitalTests/SpecCompliance/GlobalInterruptQueueACTests.swift`
  - Verify: announcement / data-source reminder / paywall 不互卡
  - ZenOS: `228280a62c1b4d79841f981dcf6d0513` → done (2026-04-23)

## Decisions
- 2026-04-23: Queue host 掛在 `ContentView` app root，同一個 production interrupt 只允許一個 active presenter。
- 2026-04-23: 第一階段先收 announcement、data-source reminder、paywall 三條 production 熱點，不擴大到 feature-local edit sheets。
