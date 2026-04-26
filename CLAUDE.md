# CLAUDE.md — iOS App (Swift)

> **Shared project-wide constraints** (never fabricate, evidence-first, mock boundaries, no deploy, no auto-commit, own problems, i18n/timezone, environment table, cross-repo architecture) live in `../../../CLAUDE.md` and load automatically via stacking. This file is iOS-specific only.

## iOS-Specific Constraints

1. **`Date` is NOT a valid Dictionary key.** Use `TimeInterval`. `Date`'s `Hashable` is time-dependent → silent runtime crash, no compile error.

2. **Filter `NSURLErrorCancelled` before touching UI state.** Cancelled tasks are intentional navigation; showing `ErrorView` for them is a UX lie.

3. **ViewModel depends on Repository Protocol, never `RepositoryImpl`.** Concrete impl breaks DI and forces unit tests to wire the full stack.

4. **Repository never publishes to `CacheEventBus`.** Repository is passive data access; event flow belongs to ViewModels/Services. Correct pattern:

   ```swift
   // Data layer
   private let refreshSubject = PassthroughSubject<Void, Never>()
   var workoutsDidRefresh: AnyPublisher<Void, Never> { refreshSubject.eraseToAnyPublisher() }
   refreshSubject.send()   // ← NOT CacheEventBus.shared.publish

   // Presentation layer
   repository.workoutsDidRefresh
       .sink { CacheEventBus.shared.publish(.dataChanged(.workouts)) }
       .store(in: &cancellables)
   ```

   Regression check:
   ```bash
   grep -rn "CacheEventBus" Havital/Features/*/Data/ Havital/Features/*/Domain/ Havital/Core/Data/
   # expected: no matches
   ```

5. **HealthKit → Backend → UI.** Never `HealthKit → UI` directly — creates split truth between HealthKit and Firestore.

## Commands

```bash
# Build (always iPhone 17 Pro — UDID 237D67B5-E7D0-4057-A8A1-F4FEDBC6875D)
xcodebuild clean build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Maestro UI tests (never use --no-window; user needs to see the screen)
maestro test .maestro/flows/<flow>.yaml

# Find Date-as-key regressions
grep -r "Dictionary.*Date\|Date.*Dictionary" Havital/ --include="*.swift"
```

## Architecture

Full rules: @.claude/rules/architecture.md

Layering: `Presentation → Domain → Data → Core` (inward only).

- **DTO** in Data layer (snake_case + `CodingKeys`).
- **Entity** in Domain (camelCase, no Codable — couples Domain to serialization format).
- **Singleton**: HTTPClient, Logger, DataSource, Mapper, RepositoryImpl.
- **Factory** (new per use): ViewModel.

## Known Gotchas

- **TaskManageable** — every ViewModel/Manager implements it. `TaskRegistry` with unique `TaskID`. `cancelAllTasks()` in deinit. Never update UI state for cancelled tasks.
- **Init order** is strict — race conditions invisible in unit tests:
  `App Launch → Auth → User Data → Training Overview → Weekly Plan → UI Ready`
- **API call tracking** — chain `.tracked(from: "ViewName: functionName")` on every API call. Without this, production incidents are unattributable.
- **Naming trap** — product name is **Paceriz**, bundle ID stays `com.havital.*`, directory stays `Havital`.

## Role-Specific Rules

@.claude/rules/debugging.md — bug triage, root cause protocol
@.claude/rules/delivery.md — build gate, new feature checklist
@.claude/rules/testing.md — QA protocol, simulator rules, Maestro usage
@.claude/rules/multi-agent.md — agent role boundaries
