# CLAUDE.md — Paceriz iOS

## 🚨 Safety Rules (NEVER Violate)

- NEVER use `Date` as Dictionary key — causes crashes. Use `TimeInterval` instead
- NEVER let HealthKit data bypass backend: `HealthKit → Backend API → UI`, not `HealthKit → UI`
- NEVER show ErrorView for cancelled tasks — filter `NSURLErrorCancelled` before updating UI state
- NEVER let Repository publish/subscribe CacheEventBus events — Repository is passive
- NEVER let ViewModel depend on concrete RepositoryImpl — depend on Protocol only

---

## Workflow

### 1. Plan First
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)

### 2. Verify Before Modify (CRITICAL)
- When debugging UI issues: grep ALL views that display the data, verify which one is active
- NEVER assume which view is responsible — prove it with evidence
- When user questions your approach: STOP, re-verify all assumptions, then continue

### 3. Self-Improvement Loop
- After ANY user correction: update memory files with the lesson
- Write rules that prevent the same mistake from recurring

### 4. Verification Before Done
- MUST run clean build before declaring task complete
- Ask yourself: "Would a senior engineer approve this?"

### 5. Autonomous Bug Fixing
- When given a bug report: just fix it, don't ask for hand-holding
- Go fix failing builds without being told how

---

## Common Commands

```bash
# Clean build
xcodebuild clean build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Search crash patterns
grep -r "Dictionary.*Date" Havital/ --include="*.swift"
```

---

## Naming

- Product name: **Paceriz** (all user-facing text)
- Technical identifier: `com.havital.*` (App Store continuity)
- Directory name stays `Havital`

---

## ZenOS 治理技能

若當前專案有 `skills/governance/` 目錄（透過 `/zenos-setup` 安裝），
執行對應操作前**必須先用 Read tool 讀取該文件完整內容**再執行：

- 寫文件前讀：`skills/governance/document-governance.md`
- 建立 L2 概念前讀：`skills/governance/l2-knowledge-governance.md`
- 建立任務前讀：`skills/governance/task-governance.md`

> 若 `skills/governance/` 不存在，跳過治理流程。

---

## Architecture Constraints

Detailed rules: @.claude/rules/architecture.md

**Core rule**: 4-layer Clean Architecture, dependencies always point inward.
```
Presentation → Domain → Data → Core
```

### New Feature Checklist
- [ ] ViewModel: `@MainActor`, depends on Repository Protocol
- [ ] View: rendering only, no business logic
- [ ] DTO in Data Layer, Entity in Domain Layer, Mapper to convert
- [ ] Errors converted to `DomainError`, UI uses `ViewState<T>`
- [ ] All async closures use `[weak self]`
- [ ] All dependencies via `DependencyContainer`

---

## Gotchas & Anti-patterns

### TaskManageable — YOU MUST follow
- All ViewModels/Managers implement `TaskManageable`
- Use `TaskRegistry` with unique `TaskID` (e.g., `TaskID("load_weekly_plan_\(week)")`)
- `cancelAllTasks()` in deinit
- NEVER update UI state for cancelled tasks

### API Call Tracking
- Chain `.tracked(from: "ViewName: functionName")` on all API calls

### Init Order — MUST respect
```
App Launch → Auth → User Data → Training Overview → Weekly Plan → UI Ready
```
NEVER initialize ViewModel before user auth is complete.

### ViewState
- Use `ViewState<T>` enum: `.loading`, `.loaded(data)`, `.error(error)`, `.empty`
- `.error` only for actionable errors, NEVER for cancellations
