# Review Brief — fix-interval-edit-bugs

## Implementation Approach Summary

Three targeted bug fixes were applied to two acceptance criteria:

### @ac1: 100m strides overwritten to 400m (Bug 1)
**Root cause**: `TrainingDetailEditor.swift` line 56 used `distanceKm ?? 0.4`. When the backend sends `work_distance_m = 100` but omits `work_distance_km`, the fallback was 0.4 (400m), overwriting the actual 100m value.

**Fix**: Added an intermediate fallback that converts `distanceM` (in meters) to km before applying the default:
```swift
self.workDistance = details?.work?.distanceKm
    ?? details?.work?.distanceM.map { $0 / 1000.0 }
    ?? 0.4
```

### @ac2: Stationary rest shows distance after save (Bug 2 — two sub-fixes)

**Fix A — IntervalBlockDTO explicit nil encoding**:
`IntervalBlockDTO` relied on the synthesized `Encodable`, which omits nil optional fields (using `encodeIfPresent` semantics). This caused the backend to receive no recovery fields at all, leaving old distance values in place.

Added a custom `encode(to:)` to `IntervalBlockDTO` that calls `container.encode(_:forKey:)` (not `encodeIfPresent`) for every field, so nil values are sent as JSON `null`. This follows the same pattern as `MutableWorkoutSegment.encode(to:)` and `MutableTrainingDetails.encode(to:)`.

**Fix B — recoveryDurationSeconds was hardcoded nil**:
In `EditScheduleV2ViewModel.buildRunActivityDTO`, the `IntervalBlockDTO` constructor always passed `recoveryDurationSeconds: nil`, discarding the actual `recovery.timeSeconds` value populated for stationary rests.

**Fix**: Changed to `recoveryDurationSeconds: recovery.timeSeconds` so the seconds value is correctly forwarded to the backend.

---

## AC Status

| AC | Status | Notes |
|----|--------|-------|
| @ac1 Short-distance interval preserves original distance | FIXED | distanceM fallback added |
| @ac2 Stationary rest shows no distance after save | FIXED | Both Fix A (nil encoding) and Fix B (timeSeconds forwarded) applied |

---

## Changed Files

| File | Change |
|------|--------|
| `Havital/Views/Training/EditSchedule/TrainingDetailEditor.swift` | Added `distanceM` fallback in `workDistance` initialization (line ~56) |
| `Havital/Features/TrainingPlanV2/Data/DTOs/TrainingSessionDTOs.swift` | Added custom `encode(to:)` to `IntervalBlockDTO` to explicitly encode nil fields as `null` |
| `Havital/Features/TrainingPlanV2/Presentation/ViewModels/EditScheduleV2ViewModel.swift` | Fixed `recoveryDurationSeconds: nil` → `recoveryDurationSeconds: recovery.timeSeconds` |

---

## Architecture Violations Checked

- No layer violations: all changes stay within their respective layers (Presentation/ViewModel/DTO)
- `IntervalBlockDTO` is a Data Layer struct — adding `encode(to:)` is appropriate there
- `EditScheduleV2ViewModel` already depends only on `TrainingPlanV2Repository` protocol — no change
- No new dependencies introduced
- No `Date` used as Dictionary key
- No HealthKit data bypassing backend

---

## Build Verification Output

```
** BUILD SUCCEEDED **
```

Only warnings were present (pre-existing deprecation warnings, Swift 6 concurrency warnings, script phase warnings). Zero errors.
