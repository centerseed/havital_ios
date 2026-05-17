# Badge System App Integration — Delivery Results

**Branch:** `feature/badge-system-app-integration`
**Plan:** `docs/superpowers/plans/2026-05-17-badge-system-app-integration.md`
**Spec:** `docs/superpowers/specs/2026-05-17-badge-system-app-integration-design.md`
**Delivered:** 2026-05-17

## Commits (14 tasks across 27 commits)

```
chore(celebration): /simplify pass — extract TimeFormatting + add empty-badges guards
test(celebration): add Maestro flows for badge pin and PB+badge celebration
docs(achievements): clarify two-share-path design decision (drop Task-13 TODO)
refactor(celebration): wire CelebrationSheet share to CelebrationSharePreviewSheet, delete legacy celebration modal
fix(celebration): annotate render() @MainActor + reuse existing ActivityViewController
feat(celebration): add CelebrationSharePreviewSheet with system share integration
feat(celebration): add 4:5 CelebrationShareCardView with privacy filter for sensitive fields
fix(celebration): scope badge lookup to current workout + document dedup limit
feat(celebration): fold newly unlocked badges into deriveCelebrationContent
fix(celebration): address Task 8 review feedback (@MainActor, guards, scroll height, AC coverage)
refactor(celebration): introduce CelebrationSheet supporting PB/badge/both modes
feat(achievements): add Pin/Unpin to home action in AchievementDetailView
fix(training-plan): remove km duplication in WeekOverviewCardV2 nil-badge state
feat(training-plan): show badge artwork in WeekOverviewCardV2 ring center
fix(training-plan): guard-register AchievementRepository in convenience init
feat(training-plan): expose displayBadge state on TrainingPlanV2ViewModel
fix(achievements): single source of truth for pinned badge ID + tighten emission test
chore(achievements): revert scope-creep additions from Task 3 fix commit
fix(achievements): use _road artwork for BADGE-START-FIRST-RUN, remove orphan _marker
feat(achievements): implement pin/display badge methods in AchievementRepositoryImpl
fix(achievements): enforce status validity on pinned badge selection
feat(achievements): add SelectDisplayBadgeUseCase with pin + progress-based fallback
test(achievements): cover empty-string unpin behavior in PinnedBadgeStorage
feat(achievements): add PinnedBadgeStorage for local pin persistence
feat(achievements): extend AchievementRepository protocol with pin/display badge API
```

## What shipped

### Training tab integration (Tasks 1-6)
- WeekOverviewCardV2: ring center now hosts pinned badge artwork (72px); km label moved to right column top (16pt bold)
- Ring progress (blue) semantics unchanged — still represents weekly mileage progress
- Tap ring opens AchievementDetailView sheet
- Fallback: ProgressView placeholder when displayBadge is loading

### Pin/Unpin mechanism (Task 7)
- AchievementDetailView shows Pin/Unpin button (pin/pin.fill SF Symbol)
- Local storage via `PinnedBadgeStorage` (UserDefaults)
- Algorithm fallback when no pin: most-progressed in_progress badge → most-recent unlock → first available
- Status validity enforced: only `.unlocked` / `.inProgress` badges can win the pin position

### Celebration sheet unified (Tasks 8-9)
- New `CelebrationSheet` replaces `PersonalBestCelebrationView` in 3 call sites (WorkoutDetailViewV2 / MyAchievementView / PBMomentPreviewView)
- 3-mode rendering: `.pbOnly` / `.badgesOnly` / `.pbWithBadges`
- Visual baseline of legacy PB Moment preserved exactly for the `.pbOnly` case
- WorkoutDetailViewModelV2 now derives `pendingCelebrationContent` by folding newly-unlocked badges (matched by `sourceRef.summaryParams["workout_id"]`) into the celebration

### Share card refactor (Tasks 10-12)
- New `CelebrationShareCardView` 4:5 (270x337.5 display / 1080x1350 PNG export at x4 scale)
- New `CelebrationSharePreviewSheet` with system share via `UIActivityViewController`
- Privacy filter on `exposableFields()` — case-insensitive prefix exclusion of: heart_rate, hr_, route, gps, location, coord, polyline, pace_series, split_, lap_
- All `CelebrationSheet.onShare` callbacks wired to `CelebrationSharePreviewSheet`
- Legacy `PersonalBestCelebrationView` struct removed (file retained — co-locates 5 other elements)
- `AchievementShareCardView` retained: library-tab badge share path uses different data shape (decided 2026-05-17)

### QA (Task 13)
- 2 Maestro flows: `badge-pin-and-display.yaml`, `celebration-pb-with-badge.yaml` — both pass on iPhone 17 Pro
- 11 new i18n keys verified in zh-Hant / en / ja
- Unit tests: 45 passing across 6 suites

### Simplify (Task 14)
- Extracted `Havital/Utils/TimeFormatting.swift` — `formatTime` / `formatImprovement` deduped from CelebrationSheet and CelebrationShareCardView. Formulas verified identical across all three locations before consolidation. `PersonalBestUpdate.formattedImprovement()` instance method kept as-is (different parameter source).
- `assertionFailure` guards added on empty `.badgesOnly` in both CelebrationSheet and CelebrationShareCardView

## Known follow-ups (not in this branch)

1. **WorkoutDetailViewModelV2 class-level @MainActor**: per-method annotations applied; class-wide would cascade to many call sites. Defer.
2. **`localizedOrFallback` String extension duplicated in 5 files**: pre-existing project pattern; full dedup needs shared utility + 5 file edits. Defer.
3. **Badge artwork sweep**: 20+ badge imagesets declare only single 1x scale in Contents.json. Foundation WIP item, separate concern. (Asset for FIRST-RUN badge was already fixed in `d0965d2` by switching to the `_road` variant.)
4. **AchievementShareCardView consolidation**: intentional two-path design (celebration flow + library flow). Not a follow-up — design decision.
5. **CelebrationContent `.pbWithBadges` and `.badgesOnly` Maestro visual coverage**: PBMomentPreviewView harness only supports pbOnly scenarios. E2E coverage requires harness extension or real workout trigger.
6. **Backend badge categorization (mentioned 2026-05-17)**: iOS layer trusts `dto.chapter`; categorization correctness depends on backend `cloud/api_service/` config — out of iOS scope.

## Designer review request

Please run Visual Parity Gate on this branch focusing on:

1. **WeekOverviewCardV2** — ring center badge artwork (72px) + km right-column layout balance vs. previous design
2. **CelebrationSheet** — `.pbOnly` mode should be visually identical to legacy PersonalBestCelebrationView (76pt time, gold capsule, ConfettiView, trophy mark)
3. **CelebrationSharePreviewSheet** — 4:5 card aspect, eyebrow capsule (gold for PB / orange for badge / orange for combo), privacy hint card readability
4. **AchievementDetailView** — Pin/Unpin button placement & SF Symbol toggle (pin / pin.fill)

Use `PacerizTokens.color.brand.primary` for badge ring stroke, existing `#FFD700 / #B8860B / #27AE60` for PB Moment palette. All badge artwork via `AchievementBadgeArtwork.assetName(for:)`.

Reference simulator: iPhone 17 Pro (BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4, iOS 26.4).

## How to verify locally

```bash
cd /Users/wubaizong/havital/apps/ios/Havital
xcodebuild clean build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
maestro test .maestro/flows/badge-pin-and-display.yaml
maestro test .maestro/flows/celebration-pb-with-badge.yaml
```
