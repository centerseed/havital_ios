# Review Brief: edit-warmup-cooldown

## Implementation Approach Summary

Fixed 3 data loss breakpoints in the V2 training schedule edit flow:

1. **MutableTrainingDay** (Models layer) — added `warmup: RunSegment?` and `cooldown: RunSegment?` fields. Both `init(from day: DayDetail)` and `init(from day: TrainingDay)` now read warmup/cooldown from the source. `Equatable` and `createEmpty`/custom init updated accordingly.

2. **EditScheduleV2ViewModel** (Presentation/ViewModel) — `buildDayDetailDTO` now converts `day.warmup`/`day.cooldown` to `RunSegmentDTO` and passes them to the API. Only run-category types send warmup/cooldown; strength/cross/rest always pass `nil`.

3. **TrainingDetailEditor** (Presentation/View) — `TrainingDayEditState` gains 6 new `@Published` fields (`hasWarmup`, `warmupDistance`, `warmupPace`, `hasCooldown`, `cooldownDistance`, `cooldownPace`). `init(from day:)` reads existing warmup/cooldown from `MutableTrainingDay`. `toMutableTrainingDay` writes them back using `RunSegment`. Added `needsWarmupCooldown: Bool` computed property. Added `WarmupCooldownEditorV2` view with toggle + distance picker + auto-estimated duration. Integrated into `editorSection` for all intensity types.

4. **EditScheduleViewV2** (Presentation/View) — `SimplifiedDailyCardV2.detailsView` shows a `warmupCooldownSummary` row (`🔥 暖跑 Xkm · ❄️ 緩和 Ykm`) when either is present. `updateTrainingType()` sets default warmup/cooldown for intensity types and clears them for easy/rest/cross types. Added `defaultWarmupCooldown(vdot:)` helper.

## AC Status

| AC | Scenario | Status |
|----|----------|--------|
| @ac1 | Warmup/cooldown preserved in edit mode | ✅ MutableTrainingDay reads from DayDetail.session |
| @ac2 | Warmup/cooldown preserved after save | ✅ buildDayDetailDTO passes RunSegmentDTO to API |
| @ac3 | Warmup/cooldown preserved on reorder | ✅ stored in MutableTrainingDay, survives onMove |
| @ac4 | Edit warmup distance | ✅ WarmupCooldownEditorV2 with distance picker |
| @ac5 | Edit cooldown distance | ✅ WarmupCooldownEditorV2 with distance picker |
| @ac6 | Default warmup/cooldown for new intensity | ✅ updateTrainingType() sets defaults |
| @ac7 | No warmup/cooldown for easy runs | ✅ easy/lsd/recovery/cross/rest clear warmup/cooldown |
| @ac8 | Warmup/cooldown in daily card summary | ✅ warmupCooldownSummary view in detailsView |

## Changed Files

1. `/Users/wubaizong/havital/apps/ios/Havital/.claude/worktrees/edit-warmup-cooldown/Havital/Models/MutableTrainingModels.swift`
2. `/Users/wubaizong/havital/apps/ios/Havital/.claude/worktrees/edit-warmup-cooldown/Havital/Features/TrainingPlanV2/Presentation/ViewModels/EditScheduleV2ViewModel.swift`
3. `/Users/wubaizong/havital/apps/ios/Havital/.claude/worktrees/edit-warmup-cooldown/Havital/Views/Training/EditSchedule/TrainingDetailEditor.swift`
4. `/Users/wubaizong/havital/apps/ios/Havital/.claude/worktrees/edit-warmup-cooldown/Havital/Features/TrainingPlanV2/Presentation/Views/EditScheduleViewV2.swift`

## Files NOT Changed (as required)

- `TrainingSessionModels.swift` — Domain RunSegment unchanged
- `TrainingSessionDTOs.swift` — RunSegmentDTO/DayDetailDTO unchanged
- `TrainingSessionMapper.swift` — Mapper unchanged
- `WarmupCooldownView.swift` — Display component unchanged

## Verification Results

```
** BUILD SUCCEEDED **
```

Command used:
```bash
cd /Users/wubaizong/havital/apps/ios/Havital/.claude/worktrees/edit-warmup-cooldown && \
xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -30
```
