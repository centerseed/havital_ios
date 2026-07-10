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

   Regression check (matches actual usage, not explanatory comments — the bus is a
   private-init singleton so every real coupling goes through `CacheEventBus.shared`):
   ```bash
   grep -rn "CacheEventBus\.shared" Havital/Features/*/Data/ Havital/Features/*/Domain/ Havital/Core/Data/
   # expected: no matches (registration/subscription lives in Core/DI/CacheRegistrationCoordinator)
   ```

5. **HealthKit → Backend → UI.** Never `HealthKit → UI` directly — creates split truth between HealthKit and Firestore.

## Commands

```bash
# Build (always iPhone 17 Pro — UDID BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4)
xcodebuild clean build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Maestro UI tests (never use --no-window; user needs to see the screen)
maestro test .maestro/flows/<flow>.yaml

# Find Date-as-key regressions
grep -r "Dictionary.*Date\|Date.*Dictionary" Havital/ --include="*.swift"
```

## 發版 (Release pipeline)

fastlane 已串好並實測(build+簽章含 Watch 已驗)。完整步驟 → **`fastlane/RELEASE.md`**。
- **正式發版(自動直接上傳)**:`cd apps/ios/Havital && fastlane ios release` — 自動 bump build 號(App Store/TF 最大+1)→ archive+簽章(Watch+complication,API key 自動 provisioning、本機免 profile)→ 上傳 App Store → 推 release notes → 送審(`automatic_release=false`,過審後手動 Release)。
- 只 build 給手動上傳:`fastlane ios build`(→ 開 Finder,Transporter 上傳)。查現行版本:`fastlane ios info`。
- **唯一人工關**:填 `fastlane/metadata/{zh-Hant,ja,en-US}/release_notes.txt` 三語文案並確認。
- 憑證:ASC 團隊金鑰自動載入自 `fastlane/.env.default`(不進 git);`.p8` 在 `~/.appstoreconnect/`。

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
