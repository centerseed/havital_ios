# /ship — Automated Feature Shipping Orchestrator

**Usage:** `/ship <feature-name>`

**Example:** `/ship weekly-training-summary`

**Prerequisite:** A spec must exist at `.claude/specs/<feature-name>/spec.md` (created by `/plan` or `/spec`).

---

## Project Config

> When porting to another project, only modify this section.

```yaml
VERIFY_APP: |
  xcodebuild clean build \
    -project Havital.xcodeproj \
    -scheme Havital \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" | tail -20
  xcodebuild test \
    -project Havital.xcodeproj \
    -scheme HavitalTests \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    2>&1 | grep -E "(Test Case|error:|passed|failed|BUILD SUCCEEDED|BUILD FAILED)" | tail -40

DB_SCHEMA_PATH: none

DEPLOY_SCRIPTS:
  app: none
DEPLOY_ORDER: []

ARCHITECTURE_RULES: |
  - 4-layer Clean Architecture: Presentation → Domain → Data → Core
  - Dependencies always point inward; inner layers NEVER import outer layers
  - ViewModel: @MainActor, depends on Repository Protocol only (NEVER concrete RepositoryImpl)
  - View: rendering only, zero business logic
  - DTO in Data Layer (snake_case + CodingKeys), Entity in Domain Layer (camelCase, no Codable)
  - Use Mapper to convert DTO ↔ Entity; NEVER expose Codable in Domain
  - All errors converted to DomainError; UI uses ViewState<T> (.loading/.loaded/.error/.empty)
  - NEVER use Date as Dictionary key (crashes) — use TimeInterval instead
  - NEVER show ErrorView for cancelled tasks — filter NSURLErrorCancelled
  - HealthKit data flow: HealthKit → Backend API → WorkoutV2 Models → UI (NEVER bypass backend)
  - All ViewModels implement TaskManageable, use TaskRegistry with unique TaskID
  - cancelAllTasks() in deinit; NEVER update UI for cancelled tasks
  - All async closures use [weak self]
  - All dependencies via DependencyContainer
  - CacheEventBus replaces NotificationCenter; Repository is passive (no publish/subscribe)
  - Dual-track caching: Track A (local cache) + Track B (background API refresh)

E2E_SKILLS:
  app: /ios-ui-test (iOS Simulator MCP — tap/swipe/screenshot/describe)

DEP_INSTALL:
  app: none
```

---

## Orchestration Flow

```
Phase 1: Setup → Phase 2: Implement → Phase 3: Review → Phase 4: Verify
    → Phase 5: Fix Loop (if needed) → Phase 6: E2E → Phase 7: Report
```

### Context Discipline Rule

The orchestrator MUST NOT read raw test output, full diffs, or verbose logs directly.
Every subagent MUST write a structured summary file. The orchestrator reads ONLY summary/verdict files.

Subagent output files (all under `.claude/specs/<feature-name>/`):
- `review-brief.md` — Phase 2 implementation summary
- `review-report.md` — Phase 3 PASS/NEEDS_REWORK verdict
- `fix-list.md` — Phase 3/5 blocking issues
- `verify-result.md` — Phase 4/5 structured pass/fail table
- `e2e-result.md` — Phase 6 E2E pass/fail table
- `ship-report.md` — Phase 7 final report

---

## Phase 1: Setup

1. Read `.claude/specs/<feature-name>/spec.md`. If it doesn't exist, STOP and tell the user to run `/plan <feature-name>` first.
2. Parse spec metadata: `affected`, `db_migration`, `deploy_required`.
3. Create a git worktree for isolation:
   ```bash
   git worktree add .claude/worktrees/<feature-name> -b ship/<feature-name>
   ```
4. Install dependencies in worktree for each affected platform (see `DEP_INSTALL` in Project Config).
5. If `db_migration: true`, snapshot the DB schema:
   ```bash
   cp <DB_SCHEMA_PATH> /tmp/db-schema-before
   ```
6. Copy the spec file into the worktree for subagent access.

---

## Phase 2: Implementation (Subagent in Worktree)

Launch an **implementation subagent** (Sonnet model, worktree isolation) with this mandate:

### Subagent Instructions

```
You are an implementation engineer working in a git worktree.
Working Directory: .claude/worktrees/<feature-name>

Read the spec at .claude/specs/<feature-name>/spec.md — this is your contract.

## ━━━ Phase 0: Codebase-First Exploration (MANDATORY before any code) ━━━

Never assume. Never invent. Always verify with search tools first.

1. **Read the affected area** — open and read every file listed in spec's "Files Expected to Change" + their neighbors
2. **Find your reference implementation** — search for the closest existing feature to what you're building. This is your north star for style, patterns, and naming.
3. **Grep before creating** — before writing ANY new function, class, type, or utility:
   - Search the entire codebase for existing implementations: `grep -r "functionName\|similar_keyword"`
   - If something similar exists, REUSE it. If it needs extension, EXTEND it. Only create new if nothing exists.
4. **Learn the naming conventions** — read 3-5 existing files in the same layer/module to extract:
   - File naming pattern (what suffix — ViewModel, Repository, Service, UseCase?)
   - Export naming pattern
   - Variable/function naming (camelCase, what prefixes?)
   - Type/Protocol naming conventions
   - Test file location (HavitalTests/ — what suffix .Tests.swift?)
5. **Map the dependency chain** — for each file you'll touch, understand what imports it and what it imports. Never break existing consumers.

OUTPUT of Phase 0: Write a brief note (in your working memory, not a file) listing:
- Reference implementation file path
- Naming conventions discovered
- Existing utilities you'll reuse
- Files you'll create vs. edit

## ━━━ Phase 1: TDD Implementation (per AC, strict order) ━━━

### The Iron Law: RED → GREEN → REFACTOR
For EACH acceptance criterion, in strict order:
1. **RED** — Write a FAILING test. Run it. Watch it fail. If it passes immediately, your test is wrong — delete and rewrite.
2. **GREEN** — Write the MINIMAL production code to make it pass. Run it. Confirm green.
3. **REFACTOR** — Clean up while keeping green. Run tests again.

NO production code without a failing test first. No exceptions.
"I'll add tests later" = NO. "It's too simple to test" = NO. "Manual testing is sufficient" = NO.

### Test Quality Rules (Swift/XCTest specific)

**Mutation Resistance (MOST IMPORTANT)**:
- Every XCTAssert must BREAK if someone flips a condition, changes a constant, or removes a line
- `XCTAssertNotNil(result)` alone is NEVER sufficient — assert specific values, counts, state changes
- If code checks `> 0`, you MUST test with -1, 0, and 1
- If a method updates multiple fields, assert ALL of them
- Ask yourself: "If I delete line X of production code, does any test fail?" — if no, add one

**No Tautological Mocks**:
- Mock ONLY external I/O (network, HealthKit, UserDefaults) — everything else runs real
- NEVER: mock returns X → assert result is X (you tested the mock, not the code)
- NEVER: add test-only methods to production code
- If your test would still pass with the function body replaced by `return mockValue`, it tests nothing

**Assertion Density**:
- Minimum 3 meaningful XCTAssert per test (return value + side effects + state)
- Assert the THEN condition from the AC with specific values, not just "no crash"

**Mandatory Edge Cases** (at least one per AC):
- nil, empty array, zero
- Boundary values (off-by-one)
- Cancelled async tasks (NSURLErrorCancelled)
- Unauthorized access

**Test Naming**: `test_<method>_<condition>_<expectedResult>()` or `testGiven_When_Then()`

**Max 10 tests per file**: Focus on high-value behavioral tests covering real user flows.

**Fix Code, Not Tests**: If a test fails during GREEN phase, the implementation is wrong. Never weaken a test to make it pass.

### Anti-Patterns (Immediate Red Flags for Swift)
- Test passes immediately on RED → proves nothing, DELETE and rewrite
- Mock returns expected value, test asserts it back → tautology, REWRITE
- Testing @Published property directly without awaiting the publisher → race condition
- Using force-unwrap `!` in production code → crash risk, use guard/if let
- Not using [weak self] in async closures → retain cycle
- Updating UI from background thread → crash, always use @MainActor or DispatchQueue.main

## ━━━ Phase 2: Implementation Discipline ━━━

### iOS Architecture Rules (MUST follow)
- ViewModel: `@MainActor`, depends on Repository Protocol only
- View: SwiftUI rendering only, no business logic, no direct API calls
- All ViewModels implement `TaskManageable`, use `TaskRegistry` with unique `TaskID`
- `cancelAllTasks()` in deinit
- NEVER update ViewState for cancelled tasks (.error only for actionable errors)
- NEVER use `Date` as Dictionary key — use `TimeInterval`
- All async closures: `[weak self]`
- All dependencies via `DependencyContainer`

### DRY: Search Before You Create
- Before creating a new file → glob/grep for similar files. Does one already exist?
- Before creating a new function → search for existing functions with similar names or purposes
- Before creating a new type → check if a domain entity already models this concept
- If you find yourself copying code from another file → extract a shared utility instead

### Consistency: Follow, Don't Invent
- Match the EXACT patterns from your Phase 0 reference implementation
- Same import ordering style, same error handling pattern, same logging approach
- If existing code uses specific naming patterns, follow them exactly

### Simplicity: YAGNI
- Solve each AC in order — do NOT jump ahead or parallelize
- Write the simplest code that passes the test — no speculative features
- Don't add configurability or options not in the spec
- Prefer editing existing files over creating new ones

### Error Handling
- All errors → DomainError or logged — never swallow silently
- For async operations: always handle cancellation (NSURLErrorCancelled → ignore, don't show error)
- Cancelled tasks: NEVER update ViewState to .error

### Boundaries: Don't Touch What You Shouldn't
- Do NOT add comments, docstrings, or annotations to code you didn't write
- Do NOT refactor existing code unless it's blocking your implementation
- Do NOT "improve" code quality of files outside your spec scope

## ━━━ PAUSE Gates ━━━

If you encounter any of these, output the exact marker and STOP:
- [PAUSE:DB_MIGRATION] <description of schema change needed>
- [PAUSE:DATA_DELETE] <description of data that would be deleted>

## ━━━ Architecture Rules ━━━

- Clean Architecture: Presentation → Domain → Data → Core
- Outer layers depend on inner; inner NEVER imports outer
- NEVER use Date as Dictionary key
- NEVER let HealthKit data bypass backend API
- NEVER show ErrorView for NSURLErrorCancelled
- Repository is passive: no CacheEventBus publish/subscribe
- ViewModel depends on Repository Protocol, NEVER on RepositoryImpl

## ━━━ Adversarial Self-Review (before declaring done) ━━━

Before running final verification, attack your own code:
1. **Race conditions** — can two concurrent async tasks corrupt @Published state?
2. **Null/empty edges** — what if input is nil, empty array, zero?
3. **Memory leaks** — did all async closures use [weak self]?
4. **Cancelled task leaks** — does cancelAllTasks() in deinit cover all tasks?
5. **Regression** — did you accidentally change behavior of existing features?
6. **Architecture violations** — any ViewModel depending on concrete impl? Any Date as Dictionary key?
7. **Naming audit** — do all your new names match the conventions discovered in Phase 0?

If you find issues, fix them before proceeding.

## ━━━ Verification (MANDATORY — no claims without evidence) ━━━

Run the verification commands from Project Config:
```bash
xcodebuild clean build \
  -project Havital.xcodeproj \
  -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" | tail -20

xcodebuild test \
  -project Havital.xcodeproj \
  -scheme HavitalTests \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "(Test Case|error:|passed|failed|BUILD SUCCEEDED|BUILD FAILED)" | tail -40
```

Rules:
- Run the FULL command. Read the FULL output. Check exit codes.
- "Should compile" / "looks correct" / "probably passes" = NOT VERIFIED. Run it.
- If verification fails, fix the issue and re-run. Do NOT declare done with failing build/tests.
- Copy-paste the actual terminal output as evidence.

## ━━━ Output ━━━

When done, write .claude/specs/<feature-name>/review-brief.md containing:
- Implementation approach summary
- Reference implementation used (which existing feature you followed)
- Naming conventions followed (with examples)
- Existing utilities reused (list them)
- AC status (checked/unchecked with explanation)
- Key decisions made
- Changed files list (new files vs. edited files, clearly marked)
- Architecture violations checked (list each safety rule from CLAUDE.md you verified)
- Adversarial self-review findings (what you checked, what you found)
- Verification command results (copy-paste actual terminal output)
```

### PAUSE Gate Handling

If the subagent outputs `[PAUSE:DB_MIGRATION]` or `[PAUSE:DATA_DELETE]`:
1. Present the details to the user
2. Wait for explicit confirmation before continuing
3. If user denies, adjust approach or STOP

---

## Phase 3: Review (Spec Review + /simplify)

Two parallel review tracks:

### Track A — Spec Reviewer (Subagent, Sonnet)

Launch a spec review subagent reading from the worktree:

```
Review the implementation against the spec. You are the quality gate — be thorough but fair.

Read:
- .claude/specs/<feature-name>/spec.md
- .claude/specs/<feature-name>/review-brief.md
- git diff in the worktree
- The actual test files (not just the diff — read the full test to understand coverage)

For each AC in the spec:
1. Is the GIVEN precondition properly set up in the test?
2. Is the WHEN action actually triggered (not mocked away)?
3. Does the test assert the THEN condition specifically (not just "no crash")?
4. Is there at least one error/edge case test per AC?
5. Would the test catch a regression if someone broke this feature later?

iOS-specific checks:
- Are cancelled task errors (NSURLErrorCancelled) properly filtered?
- Are all @Published state updates on @MainActor?
- Are all async closures using [weak self]?
- Is cancelAllTasks() called in deinit?
- Is Date never used as Dictionary key?

Anti-patterns to flag:
- Tests that only check "XCTAssertNotNil" without verifying specific values
- XCTestExpectation used incorrectly (not fulfilled, wrong count)
- UI state updated from background thread
- AC marked as done but no corresponding test exists

Verdict: PASS | NEEDS_REWORK
If NEEDS_REWORK, list each blocking issue as:
- [BLOCK] file:line — description — which AC is affected
```

### Track B — /simplify (Code Quality + Reuse + Efficiency)

Run the `/simplify` skill on the worktree changes. This is a built-in skill that launches **3 parallel review agents**:

1. **Code Reuse Review** — searches codebase for existing utilities that could replace newly written code, flags duplicate functionality, finds inline logic that could use existing helpers
2. **Code Quality Review** — catches redundant state, parameter sprawl, copy-paste with variation, leaky abstractions, missing [weak self] in closures
3. **Efficiency Review** — flags unnecessary work, missed async/await patterns, N+1 API calls, memory leaks, overly broad operations

`/simplify` not only finds issues — **it fixes them directly**. This eliminates one round of fix loop for quality issues.

### Combine Results

After both tracks complete:
- Write `.claude/specs/<feature-name>/review-report.md` combining Spec Reviewer verdict + /simplify summary
- If Spec Reviewer says NEEDS_REWORK, create `.claude/specs/<feature-name>/fix-list.md` with blocking issues
- /simplify fixes are already applied — only Spec Reviewer blocking issues enter the fix loop

---

## Phase 4: Unit Test Verification (Subagent)

Launch a **verification subagent** (Sonnet model, worktree):

```
Working Directory: .claude/worktrees/<feature-name>

Run verification commands:
1. xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 16'
2. xcodebuild test -project Havital.xcodeproj -scheme HavitalTests -destination 'platform=iOS Simulator,name=iPhone 16'

Run the FULL command. Read the FULL output. Check exit codes.

Write .claude/specs/<feature-name>/verify-result.md:

| Suite | Result | Passed | Failed | First Error (if any) |
|-------|--------|--------|--------|----------------------|

Include exit code for each command.
```

Orchestrator: read ONLY `verify-result.md`. Do NOT read raw test output.

---

## Phase 5: Fix Loop (Subagent per Iteration)

```
iteration = 0
while (has_blocking_issues OR verification_failed) AND iteration < 3:
    iteration++

    Launch **Fix-Review-Verify subagent** (Sonnet, worktree):
        - Read fix-list.md and/or verify-result.md
        - For each [BLOCK] item: read the referenced file in full, understand the context, then fix
        - Fix ONLY the flagged issues — no new features, no refactoring, no "while I'm here" changes
        - If a fix would require architectural changes beyond the scope, flag as ESCALATE
        - Re-run spec review (Track A logic from Phase 3)
        - Re-run verification commands
        - Write updated:
          - fix-list.md (FIXED / ESCALATE / STILL_BROKEN)
          - verify-result.md (structured table)
          - review-report.md (updated verdict)

    Orchestrator reads ONLY verdict from review-report.md + pass/fail from verify-result.md.

if iteration == 3 AND still failing:
    STOP and report to user
    Keep worktree intact for manual intervention
    Print: "Fix loop exhausted after 3 iterations. Worktree preserved at .claude/worktrees/<feature-name>"
```

---

## Phase 6: Merge & E2E Testing

Only reached if Phase 3+4+5 all pass.

### 6a: Merge Worktree

```bash
# From main repo
git merge ship/<feature-name>
# Clean up worktree
git worktree remove .claude/worktrees/<feature-name>
```

### 6b+6c: E2E Testing (Subagent)

Launch an **E2E subagent** (Sonnet model, main repo):

```
Run E2E tests using iOS Simulator MCP for affected features from the spec.
Use /ios-ui-test patterns:
- Launch the app on simulator
- Navigate to the affected screen
- Test the user flows from each AC
- Take screenshots at key points
- Verify visual correctness

If E2E fails, fix in main repo and retry (max 2 iterations).

Write .claude/specs/<feature-name>/e2e-result.md:
| Platform | Result | Flows Tested | Flows Passed | Fix Iterations |
If FAILED after retries, include first failure description (max 10 lines).
```

Orchestrator: read ONLY `e2e-result.md`.

---

## Phase 7: Report

Write `.claude/specs/<feature-name>/ship-report.md`:

```markdown
# Ship Report: <feature-name>

## Result: SUCCESS | PARTIAL | FAILED

## AC Status
- [x] AC1: <name> — PASS (unit + e2e verified)
- [x] AC2: <name> — PASS (unit verified)
- [ ] AC3: <name> — FAILED (reason)

## Test Results
| Suite | Result | Details |
|-------|--------|---------|
| iOS build | PASS | BUILD SUCCEEDED |
| Unit tests | PASS | 42 passed, 0 failed |
| E2E app | PASS | 3/3 flows passed |

## Review Verdicts
- Spec Review: PASS
- Code Quality: PASS

## Fix Loop Iterations: N

## Changed Files
- `Havital/Features/path/to/File.swift` — description

## Deployment
- Required: no (App Store submission manual process)
- Status: DONE (code merged to branch)
```

### Deployment Note

iOS apps are deployed via App Store Connect — no automated deploy scripts.
If the feature requires a new app release, notify the user to submit via Xcode.

---

## PAUSE Gates Summary

| Trigger | Detection | Action |
|---------|-----------|--------|
| DB Schema Change | spec `db_migration: true` | Ask user to confirm |
| Test Data Deletion | Subagent outputs `[PAUSE:DATA_DELETE]` | Ask user to confirm |
| Permission Error | Subagent auth failure | Ask user |
| Fix Loop Exhausted | 3 unit iterations or 2 E2E iterations | STOP, preserve worktree, report |

---

## Model Assignment

| Role | Phase | Model |
|------|-------|-------|
| Orchestrator (this command) | all | Inherits user's session model |
| Implementation subagent | 2 | Sonnet |
| Spec Reviewer | 3 | Sonnet |
| /simplify (Code Quality) | 3 | Built-in skill (launches 3 internal agents) |
| Verification subagent | 4 | Sonnet |
| Fix-Review-Verify subagent | 5 | Sonnet |
| E2E subagent | 6 | Sonnet |

---

## CRITICAL BOUNDARIES

- **Never skip TDD** — every AC must have a failing test before production code
- **Never bypass PAUSE gates** — always wait for user confirmation
- **Never auto-deploy** — iOS deployment always requires user action (App Store Connect)
- **Never exceed fix loop limits** — 3 for unit, 2 for E2E, then STOP
- **Respect CLAUDE.md safety rules** — especially Date-as-key crash and NSURLErrorCancelled filter
- **Keep worktree on failure** — user may want to inspect or continue manually
