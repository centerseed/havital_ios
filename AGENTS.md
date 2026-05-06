# AGENTS.md — Paceriz iOS

## Workspace Map

- iOS app: `/Users/wubaizong/havital/apps/ios/Havital`
- Backend API service: `/Users/wubaizong/havital/cloud/api_service`
- When a feature crosses app/backend boundaries, inspect and update both paths in the same task unless the user explicitly scopes the work to one side.

## Codex Skill Policy

- Canonical shared agent skills live in `~/.codex/skills`.
- This iOS repo keeps only project-specific Codex skills in `.codex/skills/`:
  - `audit-prod-health`
  - `audit-gemini-usage`
  - `audit-weekly-plan`
- Do not add duplicate role/workflow skills under `.agents/skills/` or `skills/**/SKILL.md`; those copies are intentionally disabled as `SKILL.md.disabled`.
- Keep governance reference docs under `skills/governance/` as plain docs, not loadable Codex skills.

## Hard Constraints

1. **Never fabricate results.** If you haven't run it, you don't know. Say "unverified" — not "should work" or PASS. Fabricated results cost 10x more to debug than honest unknowns.

2. **Own all problems.** Build fails: fix it. QA fails: find root cause. "I don't have simulator access" is false — you have MCP tools (`mcp__ios-simulator__*`). Never push investigation back to the user.

3. **`Date` is not a valid Dictionary key.** Use `TimeInterval`. Date's Hashable is time-dependent — silent runtime crash, no compile error.

4. **HealthKit data must go through backend.** `HealthKit → Backend API → UI`, never `HealthKit → UI`. Bypassing backend creates split truth between HealthKit and Firestore.

5. **Filter `NSURLErrorCancelled` before touching UI state.** Cancelled tasks are intentional navigation — showing ErrorView for them is a UX lie.

6. **ViewModel depends on Repository Protocol, never RepositoryImpl.** Concrete impl breaks DI and makes unit testing require full wiring rewrite.

7. **Repository never touches CacheEventBus.** Repository is passive data access. Event flow belongs to ViewModels/Services — mixing it in creates hidden coupling that breaks layer independence.

   **Correct pattern** — Repository exposes a Combine publisher; ViewModel subscribes and republishes:
   ```swift
   // Repository (Data layer)
   private let refreshSubject = PassthroughSubject<Void, Never>()
   var workoutsDidRefresh: AnyPublisher<Void, Never> { refreshSubject.eraseToAnyPublisher() }
   // on background refresh success:
   refreshSubject.send()   // ← NOT CacheEventBus.shared.publish

   // ViewModel (Presentation layer)
   repository.workoutsDidRefresh
       .sink { CacheEventBus.shared.publish(.dataChanged(.workouts)) }
       .store(in: &cancellables)
   ```

   **Check for regressions:**
   ```bash
   grep -rn "CacheEventBus" Havital/Features/*/Data/ Havital/Features/*/Domain/ Havital/Core/Data/
   # expected: no matches
   ```

8. **Firestore Python SDK always requires native DNS.** Before any backend command that imports `firebase_admin`, creates a Firestore client, or calls user/training services, set `GRPC_DNS_RESOLVER=native`. This is mandatory for prod/dev reads and writes; missing it causes hangs that look like Firestore slowness.

   ```bash
   GRPC_DNS_RESOLVER=native .venv/bin/python <script>
   GRPC_DNS_RESOLVER=native conda run -n api python <script>
   ```

9. **For local prod Firestore batch reads, reuse the proven REST path.** The successful Firestore → SQL migrations do not rely on ad hoc Firebase SDK setup. Follow `cloud/api_service/scripts/backfill_workout_v2_sql_all_users.py`: set `GRPC_DNS_RESOLVER=native`, build `google.auth.default(scopes=["https://www.googleapis.com/auth/datastore"])`, wrap it in `google.auth.transport.requests.AuthorizedSession`, then call Firestore REST with decode helpers. Do not infer that Firestore is unreadable from one service-account JSON or from a hanging SDK call.

## Commands

```bash
# Build (always iPhone 17 Pro)
xcodebuild clean build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Find Date-as-key crashes
grep -r "Dictionary.*Date\|Date.*Dictionary" Havital/ --include="*.swift"
```

## Architecture

Full rules: @.Codex/rules/architecture.md

```
Presentation → Domain → Data → Core  (dependencies always inward)
```

- DTO in Data layer (snake_case + CodingKeys), Entity in Domain (camelCase). Never add Codable to Entity — couples Domain to serialization format.
- Singleton: HTTPClient, Logger, DataSource, Mapper, RepositoryImpl. Factory (new per use): ViewModel.

## Known Gotchas

**TaskManageable** — every ViewModel/Manager must implement it. `TaskRegistry` with unique `TaskID`. `cancelAllTasks()` in deinit. Never update UI state for cancelled tasks.

**Init order is strict — race conditions are invisible in unit tests:**
```
App Launch → Auth → User Data → Training Overview → Weekly Plan → UI Ready
```

**API call tracking** — chain `.tracked(from: "ViewName: functionName")` on every API call. Without this, production incidents are unattributable.

**Naming trap** — product name is **Paceriz** (user-facing), bundle ID stays `com.havital.*` (App Store continuity), directory stays `Havital`.

## ZenOS Governance

If `skills/governance/` exists, read before acting:
- Writing docs → `document-governance.md`
- Creating L2 concepts → `l2-knowledge-governance.md`
- Creating tasks → `task-governance.md`

## Role-Specific Rules

@.Codex/rules/debugging.md — bug triage, root cause protocol
@.Codex/rules/delivery.md — build gate, new feature checklist
@.Codex/rules/testing.md — QA protocol, simulator rules, Maestro usage
@.Codex/rules/multi-agent.md — agent role boundaries
