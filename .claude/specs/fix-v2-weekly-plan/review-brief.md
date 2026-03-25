# Review Brief: fix-v2-weekly-plan

## Implementation Approach

Two minimal, targeted bug fixes following the spec contract exactly.

### AC1 — App Background/Foreground Refresh
Added `.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification))` after the existing `.task` block in `TrainingPlanV2View`. When triggered, spawns a `Task` to call `viewModel.initialize()`, mirroring the V1 pattern in `TrainingPlanView.swift:229`.

### AC2 — Sheet Race Condition Fix
Reordered operations in `createWeeklySummaryAndShow()` so that:
1. `weeklySummary = .loaded(summary)` — set data first
2. `await refreshPlanStatusResponse()` — update plan status while loading sheet is still visible
3. Set all three loading flags to `false` — start loading sheet dismiss
4. `try? await Task.sleep(nanoseconds: 600_000_000)` — wait 0.6s for dismiss animation to complete
5. `showWeeklySummary = true` — present summary sheet only after loading sheet is fully gone

This prevents SwiftUI's silent sheet discard that occurred when two sheet transitions overlapped.

## AC Status

| AC | Status | Verification |
|----|--------|--------------|
| @ac1 | Done | Code review + clean build |
| @ac2 | Done | Code review + clean build |

## Changed Files

| File | Change |
|------|--------|
| `Havital/Features/TrainingPlanV2/Presentation/Views/TrainingPlanV2View.swift` | Added `.onReceive(willEnterForegroundNotification)` after `.task` block (line 337) |
| `Havital/Features/TrainingPlanV2/Presentation/ViewModels/TrainingPlanV2ViewModel.swift` | Reordered `createWeeklySummaryAndShow()` success path + added 600ms sleep before `showWeeklySummary = true` |

No other files were modified. No new files were created.

## Build Verification

```
** BUILD SUCCEEDED **
```

Build ran with `xcodebuild clean build -project Havital.xcodeproj -scheme Havital -sdk iphonesimulator26.2 -destination 'generic/platform=iOS Simulator'`.

Output contained only pre-existing warnings (no new errors or warnings introduced by these changes):
- Pre-existing deprecation warnings in `StravaManager.swift` and `AppViewModel.swift`
- Pre-existing Swift concurrency warnings in `AppViewModel.swift` and `BaseDataViewModel.swift`
- Pre-existing build phase script warnings
