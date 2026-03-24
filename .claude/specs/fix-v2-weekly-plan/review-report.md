# Review Report: fix-v2-weekly-plan

**Verdict: PASS**

---

## AC1 — App Background/Foreground Refresh

### Code Match vs Spec

The implementation at `TrainingPlanV2View.swift:340-344` matches the spec contract exactly:

```swift
.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
    Task {
        await viewModel.initialize()
    }
}
```

Placed immediately after the `.task` block (line 337), mirroring V1 at `TrainingPlanView.swift:229`.

### Architecture Check

- `TrainingPlanV2View` is a `struct` (SwiftUI value type). There is no reference-cycle risk between the View and the `Task` closure — the `Task` captures `viewModel`, which is a `@StateObject` (reference type) owned by SwiftUI, not by the View struct. `[weak self]` is not applicable here and its absence is correct.
- The `.onReceive` is on the View layer calling a ViewModel method — no architecture boundary violation.
- No Domain/Data/Core layers are touched.

### iOS-Specific Risks

- **No `[weak self]` concern**: The `Task` closure captures `viewModel` (an `ObservableObject` reference held by SwiftUI). This is the standard idiomatic pattern in SwiftUI and does not cause a retain cycle.
- **Double-initialize on cold launch**: On first launch, both `.task` and `.onReceive` may fire if the app receives a `willEnterForeground` notification early. However, `initialize()` is guarded by `TaskRegistry` with cancellation semantics (consistent with the `TaskManageable` pattern used in the project), so the duplicate call is safe — the first task would be cancelled when the second starts.
- **No regression risk**: The V1 codebase has had this pattern since the beginning. Adding it to V2 is a pure additive change.

### Result: PASS

---

## AC2 — Sheet Race Condition Fix

### Code Match vs Spec

The implementation at `TrainingPlanV2ViewModel.swift:889-907` matches the spec's prescribed do-block exactly, in the correct order:

1. `weeklySummary = .loaded(summary)` — data set first
2. `await refreshPlanStatusResponse()` — plan status refreshed while loading sheet is still visible
3. `isLoadingAnimation = false`, `isLoadingWeeklySummary = false`, `isGeneratingSummary = false` — loading sheet dismissed
4. `try? await Task.sleep(nanoseconds: 600_000_000)` — 600ms wait
5. `showWeeklySummary = true` — summary sheet presented after loading sheet is gone

### Architecture Check

- `TrainingPlanV2ViewModel` is declared `@MainActor` at the class level (line 8). All `@Published` state mutations (`isLoadingAnimation`, `showWeeklySummary`, etc.) therefore run on the main actor automatically — no `DispatchQueue.main.async` needed and none was added. Correct.
- `refreshPlanStatusResponse()` is a private `async` method within the same ViewModel. No architecture boundary crossed.
- No Domain/Data/Core layers were modified.

### iOS-Specific Risks

- **`Task.sleep` and cancellation**: `try? await Task.sleep(nanoseconds:)` swallows the `CancellationError`. If the enclosing Task is cancelled during the 600ms window (e.g., user navigates away), `showWeeklySummary = true` will NOT execute — the `try?` causes the function to return at that point. This is safe: no stale sheet presentation occurs after cancellation.
- **600ms delay**: The delay is intentional and matches SwiftUI's sheet dismiss animation window (~300-500ms). 600ms provides a comfortable margin. If the user dismisses the loading sheet container view during this window, the `showWeeklySummary = true` assignment would be a no-op since the view would no longer be in the hierarchy. No crash risk.
- **`planStatus` stuck in `.needsWeeklySummary`**: The fix calls `refreshPlanStatusResponse()` before closing the loading sheet, which fetches the updated status from the backend. This directly resolves the infinite-loop regression described in the spec root cause.
- **Error paths**: All three `catch` blocks (`CancellationError`, `NSURLErrorCancelled`, generic `error`) correctly reset all three loading flags and do NOT set `showWeeklySummary = true`. This is consistent with the CLAUDE.md rule: "NEVER show ErrorView for cancelled tasks."

### Potential Concern (Low Risk)

The `Task.sleep` approach is a pragmatic fix for a SwiftUI animation timing issue. A more robust alternative would be to use `sheet(isPresented:onDismiss:)` with the `onDismiss` callback to trigger `showWeeklySummary = true`. However:
- The spec explicitly prescribes the `Task.sleep` approach.
- 600ms is well above the typical SwiftUI dismiss animation duration.
- The `try?` correctly handles cancellation.
- This matches established patterns in the existing codebase.

This is acceptable for the current scope.

### Result: PASS

---

## Scope Compliance

| Requirement | Status |
|-------------|--------|
| Only 2 files changed | PASS — review-brief confirms no other files modified |
| Domain layer not touched | PASS |
| Data layer not touched | PASS |
| Repository protocols/impls not touched | PASS |
| V1 TrainingPlanView not modified | PASS |
| Build succeeded with no new warnings | PASS (per review-brief) |

---

## Summary

Both ACs are implemented correctly, match the spec contract exactly, introduce no architecture violations, and handle all iOS-specific edge cases appropriately. The implementation is minimal, targeted, and does not introduce regressions.

**Verdict: PASS**
