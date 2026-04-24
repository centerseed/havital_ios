# CLAUDE.md — Paceriz iOS

## Related Projects (讀這兩份前置 CLAUDE.md)

這個 repo 只負責 iOS App。完整 Paceriz 產品還有另外兩個 repo，改動前必讀對應的 CLAUDE.md：

| Project | Path (from repo root `/Users/wubaizong/havital/`) | Must-read |
|---------|------|-----------|
| ⚙️ Backend API service | `cloud/api_service/` | `cloud/api_service/CLAUDE.md` |
| 🌐 Official website | `web/official_web/` | `web/official_web/README.md` |

跨 repo 工作守則：
- 呼叫的 API 行為有問題 → 先跑 HTTP call + 看 Firestore 驗證是 backend 還是 App 側問題；讀 `cloud/api_service/CLAUDE.md` 了解 V1/V2/V3 path 陷阱再動手
- 新增 endpoint 或改 payload → 必須在 `cloud/api_service/` 確認對應 route 存在並符合 iOS 期待，不得假設後端會配合
- 三個 repo 的 `CLAUDE.md` 互不繼承，每個都是獨立 SSOT——別假設後端也遵守 iOS 的某條規則

Repo root 的 `/Users/wubaizong/havital/CLAUDE.md` 有專案總覽、環境對照、命名慣例；跨 repo 決策需要背景時讀它。

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

## Commands

```bash
# Build (always iPhone 17 Pro)
xcodebuild clean build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Find Date-as-key crashes
grep -r "Dictionary.*Date\|Date.*Dictionary" Havital/ --include="*.swift"
```

## Architecture

Full rules: @.claude/rules/architecture.md

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

@.claude/rules/debugging.md — bug triage, root cause protocol
@.claude/rules/delivery.md — build gate, new feature checklist
@.claude/rules/testing.md — QA protocol, simulator rules, Maestro usage
@.claude/rules/multi-agent.md — agent role boundaries
