# 週回顧自由文字 NL 入口 (iOS, T-0029) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓用戶在 iOS 週回顧畫面用自由文字告訴 Rizo 下週想怎麼調整課表（延後捕捉，下次生成下週課表時自動套用）。

**Architecture:** iOS 為主。送出複用既有 `RizoRepository.sendChat(scenario:"weekly_situation")`（打 `/v2/agent/chat`）；狀態走既有週回顧 summary（DTO 加 `user_nl_edit`/`status` 欄位）。後端 deferred 鏈核心已備已部署，只補小洞：輸入驗證、`deferred_stored` 回饋旗標、i18n、優先序測試。

**Tech Stack:** Swift / SwiftUI / @Observable（iOS）；Python / FastAPI / pytest（後端）。後端 spec 見 `docs/superpowers/specs/2026-06-23-weekly-review-nl-input-ios-design.md`。

**前置事實（已現查）：**
- `RizoRepository.sendChat(scenario:String, message:String, sessionId:String?) async throws -> RizoReply`（`Havital/Features/Rizo/Domain/Repositories/RizoRepository.swift:31`）。`RizoReply.response: String` = Rizo 確認句。
- `WeeklySummaryCoordinator`（`Havital/Features/TrainingPlanV2/Presentation/ViewModels/WeeklySummaryCoordinator.swift`）是 `@Observable final class`，**已用** `DependencyContainer.shared.resolve()`（line 97/106 取 AnalyticsService）→ 同範式取 `RizoRepository`。`applySelectedAdjustments(weekOfPlan:) async -> Bool`（line 133）是要 mirror 的 async 範式。
- DTO `NextWeekAdjustmentsV2DTO`（`Features/TrainingPlanV2/Data/DTOs/WeeklySummaryV2DTO.swift:462`）；Entity `NextWeekAdjustmentsV2`（`Domain/Entities/WeeklySummaryV2.swift`，全檔 Codable）；Mapper `toNextWeekAdjustments(from:)`（`Data/Mappers/WeeklySummaryV2Mapper.swift:293`）。
- 後端：`deferred_review_edit_service.store_user_nl(uid, overview_id, summary_week, nl_text)`（`cloud/api_service/domains/agents/deferred_review_edit_service.py:21`）；weekly_situation defer 在 `orchestrator_service._chat_v2`（`orchestrator_service.py:267-341`）。

**環境提示：** 後端 `conda activate api`、測試 `./unitest.sh dev --skip-llm` 或直接 `pytest`；iOS clean build = `xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`。後端在 `cloud/api_service/`（獨立 git repo）；iOS 在 `apps/ios/Havital/`（獨立 git repo）。**兩 repo 各自 commit。**

---

## Part A — 後端小範圍補洞（先做，iOS 依賴 deferred_stored + i18n）

### Task 1：`store_user_nl` 輸入驗證（trim / 非空 / ≤2000）

**Files:**
- Modify: `cloud/api_service/domains/agents/deferred_review_edit_service.py:21-26`
- Test: `cloud/api_service/tests/unit/domains/agents/test_deferred_store_user_nl_validation.py`（Create）

- [ ] **Step 1: 寫失敗測試**

```python
"""store_user_nl 輸入驗證:空/空白拒收、超長截斷或拒收、正常 trim 後存。"""
import pytest
from unittest.mock import patch


def _svc():
    from domains.agents.deferred_review_edit_service import deferred_review_edit_service
    return deferred_review_edit_service


def test_empty_text_rejected():
    with pytest.raises(ValueError):
        _svc().store_user_nl(uid="u1", overview_id="ov1", summary_week=1, nl_text="   ")


def test_overlong_text_rejected():
    with pytest.raises(ValueError):
        _svc().store_user_nl(uid="u1", overview_id="ov1", summary_week=1, nl_text="x" * 2001)


def test_valid_text_trimmed_and_stored():
    repo_path = "core.database.repositories.training_plan_repository.training_plan_repository"
    with patch(repo_path) as repo:
        repo.get_weekly_summary_v2.return_value = {"next_week_adjustments": {}}
        _svc().store_user_nl(uid="u1", overview_id="ov1", summary_week=1, nl_text="  下週減量  ")
    # update 被呼叫、user_nl_edit 已 trim
    args, kwargs = repo.update_weekly_summary_v2.call_args
    merged = (args[2] if len(args) > 2 else kwargs.get("data"))["next_week_adjustments"]
    assert merged["user_nl_edit"] == "下週減量"
    assert merged["user_nl_edit_status"] == "pending"
```

- [ ] **Step 2: 跑測試確認 FAIL**

Run: `cd cloud/api_service && conda activate api && pytest tests/unit/domains/agents/test_deferred_store_user_nl_validation.py -v`
Expected: FAIL（目前無驗證 → `test_empty_text_rejected` / `test_overlong_text_rejected` 不 raise）。

- [ ] **Step 3: 加驗證（`deferred_review_edit_service.py` `store_user_nl` 開頭）**

```python
def store_user_nl(self, *, uid: str, overview_id: str, summary_week: int, nl_text: str) -> None:
    text = (nl_text or "").strip()
    if not text:
        raise ValueError("user_nl_edit text is empty")
    if len(text) > 2000:
        raise ValueError("user_nl_edit text exceeds 2000 chars")
    nl_text = text
    # ...（既有寫入邏輯不變，用 nl_text）
```
（保留原本 merge/update 邏輯，只在最前面加上述三行 + 用 trim 後的 `nl_text`。）

- [ ] **Step 4: 跑測試確認 PASS**

Run: `pytest tests/unit/domains/agents/test_deferred_store_user_nl_validation.py -v`
Expected: 3 passed。

- [ ] **Step 5: Commit**

```bash
cd cloud/api_service
git add domains/agents/deferred_review_edit_service.py tests/unit/domains/agents/test_deferred_store_user_nl_validation.py
git commit -m "fix(rizo): validate user_nl_edit input (trim/non-empty/<=2000)"
```

---

### Task 2：`/v2/agent/chat` weekly_situation 回應帶 `deferred_stored` 旗標

**目的（紅隊 #2）：** 意圖未判成 plan-change 時不存 user_nl_edit，iOS 需從回應得知（不假裝已記下）。

**Files:**
- Modify: `cloud/api_service/domains/agents/orchestrator_service.py`（weekly_situation defer 段，~line 282-340）
- Modify: `cloud/api_service/api/v2/agent.py`（chat endpoint 回應組裝；grep `def chat` 確認欄位序列化處）
- Test: `cloud/api_service/tests/unit/domains/agents/test_deferred_stored_flag.py`（Create）

- [ ] **Step 1: 寫失敗測試**

```python
"""weekly_situation:plan-change 意圖 → 回應 deferred_stored=True;非 plan-change → False。
mock 掉 LLM 意圖判定與 store_user_nl(IO 邊界),只測旗標。"""
import asyncio
from unittest.mock import patch, MagicMock


def _run(coro):
    return asyncio.run(coro)


def test_deferred_stored_true_when_plan_change():
    from domains.agents.orchestrator_service import orchestrator_agent_service as O
    with patch.object(O, "_maybe_defer_weekly_review", return_value=True):
        result = _run(O._weekly_situation_reply(uid="u1", message="下週減量", session_id="s1"))
    assert result.get("deferred_stored") is True


def test_deferred_stored_false_when_not_plan_change():
    from domains.agents.orchestrator_service import orchestrator_agent_service as O
    with patch.object(O, "_maybe_defer_weekly_review", return_value=False):
        result = _run(O._weekly_situation_reply(uid="u1", message="今天天氣真好", session_id="s1"))
    assert result.get("deferred_stored") is False
```
> 註：實際方法名以 code 為準（`_chat_v2` 內 weekly_situation 分支）。實作時把「是否真存了 user_nl_edit」的 bool 一路帶到 chat 回應 dict 的 `deferred_stored` 欄位。若現有結構不便 unit 測，改在 `api/v2/agent.py` chat handler 層斷言回應含該欄位的整合測試。

- [ ] **Step 2: 跑測試確認 FAIL**

Run: `pytest tests/unit/domains/agents/test_deferred_stored_flag.py -v`
Expected: FAIL（回應無 `deferred_stored`）。

- [ ] **Step 3: 實作**

在 `_chat_v2` 的 weekly_situation 分支：`store_user_nl` 真的被呼叫時記 `stored = True`，否則 `False`；把 `stored` 放進回傳 dict 的 `deferred_stored`。在 `api/v2/agent.py` chat 回應序列化加 `"deferred_stored": <bool, 預設 None/缺省>`（非 weekly_situation 場景可不帶）。

- [ ] **Step 4: 跑測試確認 PASS**

Run: `pytest tests/unit/domains/agents/test_deferred_stored_flag.py -v`
Expected: 2 passed。

- [ ] **Step 5: Commit**

```bash
git add domains/agents/orchestrator_service.py api/v2/agent.py tests/unit/domains/agents/test_deferred_stored_flag.py
git commit -m "feat(rizo): return deferred_stored flag in weekly_situation chat reply"
```

---

### Task 3：deferred 通知 i18n（`edit_failed` + `edit_applied`，3 語）

**Files:**
- Modify: `cloud/api_service/domains/training_plan/services/plan_architect_agent.py:179-189`（失敗通知，改走 i18n）
- Modify: `cloud/api_service/locales/{zh-TW,ja-JP,en-US}/messages.json`（加 keys）
- Test: `cloud/api_service/tests/unit/domains/test_deferred_notification_i18n.py`（Create）

- [ ] **Step 1: 寫失敗測試**

```python
"""三語都有 rizo.deferred.edit_failed / edit_applied key。"""
import json, pathlib

LOCALES = pathlib.Path(__file__).resolve().parents[2] / "locales"


def _get(lang, dotted):
    d = json.loads((LOCALES / lang / "messages.json").read_text(encoding="utf-8"))
    for k in dotted.split("."):
        d = d[k]
    return d


def test_edit_failed_and_applied_keys_three_langs():
    for lang in ("zh-TW", "ja-JP", "en-US"):
        assert _get(lang, "rizo.deferred.edit_failed")
        assert _get(lang, "rizo.deferred.edit_applied")
```
> 註：`messages.json` 相對 `tests/` 的層數以實際為準；用 `agent_tools` 或既有 i18n 測試找正確路徑。

- [ ] **Step 2: 跑確認 FAIL**

Run: `pytest tests/unit/domains/test_deferred_notification_i18n.py -v`
Expected: FAIL（key 不存在）。

- [ ] **Step 3: 加 i18n keys + 改通知走 i18n**

`locales/zh-TW/messages.json`（`rizo.deferred` 下）：
```json
"edit_failed": "沒能套用你上週提到的調整，打開 Rizo 再跟我說一次就好。",
"edit_applied": "你上週的調整已套用到這週的課表囉。"
```
ja-JP / en-US 對應翻譯。`plan_architect_agent.py:179-189` 的 `send_data_notification(title=..., body=...)` 改用 `i18n_service` 取用戶語言文案（移除寫死中文）。

- [ ] **Step 4: 跑確認 PASS**

Run: `pytest tests/unit/domains/test_deferred_notification_i18n.py -v`
Expected: passed。

- [ ] **Step 5: Commit**

```bash
git add domains/training_plan/services/plan_architect_agent.py locales/ tests/unit/domains/test_deferred_notification_i18n.py
git commit -m "i18n(rizo): deferred edit_failed/edit_applied notifications (3 langs)"
```

---

### Task 4：優先序整合測試 — 自由文字 NL 蓋過結構化 items（紅隊 #4）

**Files:**
- Test: `cloud/api_service/tests/agent/test_deferred_nl_overrides_items.py`（Create，real LLM + dev Firestore，標 `@pytest.mark.llm`）

- [ ] **Step 1: 寫測試（real e2e，參照 `tests/agent/test_deferred_weekly_review_e2e.py` 既有 fixture）**

```python
"""優先序:結構化 item 勾「週三→長跑」+ 自由文字 NL「取消週三的強度課」→ 生成下週 →
最終課表週三非強度(NL 蓋過 items)。證明兩路不腐爛衝突、NL 最後生效。"""
import pytest

pytestmark = pytest.mark.llm


def test_nl_overrides_structured_items(deferred_summary_fixture):
    # 1. apply 結構化 item「週三改長跑」(走 apply-items → methodology_customization)
    # 2. store_user_nl(nl_text="取消週三的強度課,改成休息")
    # 3. plan_architect_agent.generate(week=下週, persist=True)
    # 4. 讀下週 weekly_plan_v2，斷言 day_index=3 的 primary.run_type 不是 interval/threshold
    ...
```
> 用 `tests/agent/test_deferred_weekly_review_e2e.py` 的 fixture/帳號範式填實。

- [ ] **Step 2: 跑（real LLM）**

Run: `cd cloud/api_service && source .env && GCP_PROJECT=havital-dev GRPC_DNS_RESOLVER=native pytest tests/agent/test_deferred_nl_overrides_items.py -v -s`
Expected: PASS（最終週三非強度）。若 FAIL = 優先序假設不成立 → **停，回報**（spec §3 前提被推翻）。

- [ ] **Step 3: Commit**

```bash
git add tests/agent/test_deferred_nl_overrides_items.py
git commit -m "test(rizo): NL overrides structured items at next-week generation"
```

---

## Part B — iOS（DTO → Entity → Mapper → Coordinator → View → FCM）

### Task 5：DTO 加 3 欄

**Files:**
- Modify: `apps/ios/Havital/Havital/Features/TrainingPlanV2/Data/DTOs/WeeklySummaryV2DTO.swift:462-473`

- [ ] **Step 1: 加欄位 + CodingKeys**

```swift
struct NextWeekAdjustmentsV2DTO: Codable {
    let items: [AdjustmentItemV2DTO]
    let summary: String
    let methodologyConstraintsConsidered: Bool
    let basedOnFlags: [String]
    let userNlEdit: String?
    let userNlEditStatus: String?
    let userNlEditFailReason: String?

    enum CodingKeys: String, CodingKey {
        case items, summary
        case methodologyConstraintsConsidered = "methodology_constraints_considered"
        case basedOnFlags = "based_on_flags"
        case userNlEdit = "user_nl_edit"
        case userNlEditStatus = "user_nl_edit_status"
        case userNlEditFailReason = "user_nl_edit_fail_reason"
    }
}
```

- [ ] **Step 2: 編譯確認**（隨 Task 7 一起 build，DTO 單獨不易單測）

- [ ] **Step 3: Commit**

```bash
cd apps/ios/Havital
git add Havital/Features/TrainingPlanV2/Data/DTOs/WeeklySummaryV2DTO.swift
git commit -m "feat(weekly-review): add user_nl_edit fields to NextWeekAdjustments DTO"
```

---

### Task 6：Entity 加欄位 + `UserNlEditStatus` enum

**Files:**
- Modify: `apps/ios/Havital/Havital/Features/TrainingPlanV2/Domain/Entities/WeeklySummaryV2.swift`（`NextWeekAdjustmentsV2` struct）

- [ ] **Step 1: 加 enum + 欄位**

```swift
enum UserNlEditStatus: String, Codable, Equatable {
    case none, pending, applied, failed
}

// 在 struct NextWeekAdjustmentsV2 內加：
let userNlEdit: String?
let userNlEditStatus: UserNlEditStatus
let userNlEditFailReason: String?
```
> Entity 全檔已 `Codable, Equatable`（既有技術債，沿用不重構，見 spec §4.2）。`UserNlEditStatus` 同樣 Codable 以相容。

- [ ] **Step 2: Commit**

```bash
git add Havital/Features/TrainingPlanV2/Domain/Entities/WeeklySummaryV2.swift
git commit -m "feat(weekly-review): add userNlEdit fields + UserNlEditStatus to entity"
```

---

### Task 7：Mapper — status 字串 → enum（未知/缺 fallback `.none`）

**Files:**
- Modify: `apps/ios/Havital/Havital/Features/TrainingPlanV2/Data/Mappers/WeeklySummaryV2Mapper.swift:293`（`toNextWeekAdjustments`）
- Test: `apps/ios/Havital/HavitalTests/.../WeeklySummaryV2MapperTests.swift`（Create 或加進既有 mapper 測試檔；先 grep `WeeklySummaryV2Mapper` 在 `HavitalTests/` 的既有測試檔）

- [ ] **Step 1: 寫失敗測試（XCTest，match 既有 mapper 測試風格）**

```swift
func test_userNlEditStatus_maps_known_and_unknown() {
    // pending → .pending
    XCTAssertEqual(mapStatus("pending"), .pending)
    XCTAssertEqual(mapStatus("applied"), .applied)
    XCTAssertEqual(mapStatus("failed"), .failed)
    // 未知字串 / nil → .none（不可崩、不可誤判 applied）
    XCTAssertEqual(mapStatus("garbage"), UserNlEditStatus.none)
    XCTAssertEqual(mapStatus(nil), UserNlEditStatus.none)
}
```
> `mapStatus` = 對 `toNextWeekAdjustments` 內 status 映射的測試包裝；可把映射抽成 `static func mapUserNlEditStatus(_ raw: String?) -> UserNlEditStatus` 以利單測。

- [ ] **Step 2: 跑確認 FAIL**

Run（在 Xcode 或 CLI）：`xcodebuild test -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:HavitalTests/WeeklySummaryV2MapperTests/test_userNlEditStatus_maps_known_and_unknown`
Expected: FAIL（映射不存在）。

- [ ] **Step 3: 實作映射**

```swift
static func mapUserNlEditStatus(_ raw: String?) -> UserNlEditStatus {
    UserNlEditStatus(rawValue: raw ?? "") ?? .none
}

// toNextWeekAdjustments(from:) 內 NextWeekAdjustmentsV2(...) 加：
//   userNlEdit: dto.userNlEdit,
//   userNlEditStatus: mapUserNlEditStatus(dto.userNlEditStatus),
//   userNlEditFailReason: dto.userNlEditFailReason
```

- [ ] **Step 4: 跑確認 PASS**

Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Havital/Features/TrainingPlanV2/Data/Mappers/WeeklySummaryV2Mapper.swift HavitalTests/...
git commit -m "feat(weekly-review): map user_nl_edit_status string->enum (fallback .none)"
```

---

### Task 8：Coordinator — lazy RizoRepository + submitUserNlEdit

**Files:**
- Modify: `apps/ios/Havital/Havital/Features/TrainingPlanV2/Presentation/ViewModels/WeeklySummaryCoordinator.swift`
- Test: `apps/ios/Havital/HavitalTests/.../WeeklySummaryCoordinatorTests.swift`（Create 或加進既有）

- [ ] **Step 1: 寫失敗測試（注入 fake RizoRepository）**

```swift
final class FakeRizoRepo: RizoRepository {
    var lastScenario: String?; var lastMessage: String?
    var stubReply = RizoReply(response: "好，記下了", sessionId: "s1" /* 其餘欄位填 default */)
    var shouldThrow: Error?
    func sendChat(scenario: String, message: String, sessionId: String?) async throws -> RizoReply {
        lastScenario = scenario; lastMessage = message
        if let e = shouldThrow { throw e }
        return stubReply
    }
    // 其餘 protocol 方法給空實作
}

func test_submit_success_sets_loaded_and_calls_weekly_situation() async {
    let fake = FakeRizoRepo()
    let coord = makeCoordinator(rizoRepository: fake)   // 注入點見 Step 3
    coord.userNlDraft = "下週減量"
    await coord.submitUserNlEdit()
    XCTAssertEqual(fake.lastScenario, "weekly_situation")
    XCTAssertEqual(fake.lastMessage, "下週減量")
    if case .loaded(let msg, _) = coord.userNlSubmitState { XCTAssertEqual(msg, "好，記下了") }
    else { XCTFail("expected .loaded") }
    XCTAssertEqual(coord.userNlDraft, "")   // draft 清空
}

func test_submit_error_sets_error_state() async {
    let fake = FakeRizoRepo(); fake.shouldThrow = URLError(.notConnectedToInternet)
    let coord = makeCoordinator(rizoRepository: fake)
    coord.userNlDraft = "下週減量"
    await coord.submitUserNlEdit()
    if case .error = coord.userNlSubmitState {} else { XCTFail("expected .error") }
}
```
> 為可注入 fake，Coordinator 加一個可選注入點（見 Step 3）。`RizoReply` 建構參數以實際 struct 為準。

- [ ] **Step 2: 跑確認 FAIL**

Expected: FAIL（`submitUserNlEdit` / `userNlSubmitState` 不存在）。

- [ ] **Step 3: 實作（mirror `applySelectedAdjustments` 範式 + 既有 lazy resolve 範式）**

```swift
// 既有檔已用 DependencyContainer.shared.resolve()(line 97/106)。加 lazy + 可注入：
@ObservationIgnored private lazy var rizoRepository: RizoRepository = _injectedRizo ?? DependencyContainer.shared.resolve()
@ObservationIgnored private let _injectedRizo: RizoRepository?   // 測試注入用;prod 走 nil→resolve

var userNlDraft: String = ""
var userNlSubmitState: ViewState<String> = .idle

func submitUserNlEdit() async {
    let text = userNlDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    userNlSubmitState = .loading
    do {
        let reply = try await rizoRepository
            .sendChat(scenario: "weekly_situation", message: text, sessionId: nil)
            .tracked(from: "WeeklySummaryCoordinator: submitUserNlEdit")
        userNlSubmitState = .loaded(reply.response)
        userNlDraft = ""
    } catch let error {
        guard !error.isCancelled else { return }   // NSURLErrorCancelled 過濾(iOS 鐵律)
        userNlSubmitState = .error(error.toDomainError())
    }
}
```
> `.tracked(from:)`、`.isCancelled`、`.toDomainError()`、`ViewState` 用既有工具（grep 既有用法）。注入點：在現有 `init(repository:...)` 加 `rizoRepository: RizoRepository? = nil` 預設參數，存進 `_injectedRizo`——**不破壞既有建構點**（預設 nil → prod 走 resolve）。

- [ ] **Step 4: 跑確認 PASS**

Expected: 2 passed。

- [ ] **Step 5: Commit**

```bash
git add Havital/Features/TrainingPlanV2/Presentation/ViewModels/WeeklySummaryCoordinator.swift HavitalTests/...
git commit -m "feat(weekly-review): submitUserNlEdit via RizoRepository (weekly_situation)"
```

---

### Task 9：View — 自由文字子區塊

**Files:**
- Modify: `apps/ios/Havital/Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift`（`AdjustmentsSectionV2`，items `ForEach` 之後）

- [ ] **Step 1: 加子區塊（純渲染，狀態由 coordinator/entity）**

```swift
// 在 AdjustmentsSectionV2 的 items ForEach 之後：
VStack(alignment: .leading, spacing: 8) {
    Text("想自己跟 Rizo 說？")
    Text("送出會覆蓋上次記下的調整 · 最多 2000 字").font(.caption).foregroundStyle(.secondary)
    TextField("例「下週五六爬山不能跑，想多休息」", text: $coordinator.userNlDraft, axis: .vertical)
        .lineLimit(1...4)
        .onChange(of: coordinator.userNlDraft) { _, new in
            if new.count > 2000 { coordinator.userNlDraft = String(new.prefix(2000)) }
        }
    Button("送出") { Task { await coordinator.submitUserNlEdit() } }
        .disabled(coordinator.userNlDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

    // 送出回應 + 狀態
    switch coordinator.userNlSubmitState {
    case .loaded(let reply): Text("🤖 \(reply)")
    case .error: Text("送出失敗，請再試一次").foregroundStyle(.red)
    default: EmptyView()
    }
    switch nextWeek.userNlEditStatus {       // nextWeek = NextWeekAdjustmentsV2 entity
    case .pending: Label("已記下，下次生成套用", systemImage: "circle.fill")
    case .applied: Label("已套用到下週課表", systemImage: "checkmark.circle.fill")
    case .failed:  Button { /* 引導重講:focus 輸入框 */ } label: { Label("沒能套用，點我再說一次", systemImage: "exclamationmark.triangle.fill") }
    case .none: EmptyView()
    }
}
```
> 文案上線前走 i18n（若該 View 既有字串已用 LocalizedString，照辦）；`ViewState` case 名以實際為準。

- [ ] **Step 2: Clean build**

Run: `xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED（zero error）。

- [ ] **Step 3: Commit**

```bash
git add Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift
git commit -m "feat(weekly-review): free-text NL sub-block in adjustments section"
```

---

### Task 10：FCM `deferred_edit_failed` 接收（深連列 stretch）

**Files:**
- Modify: `apps/ios/Havital/Havital/.../AppDelegate.swift:105`（既有 `type` 分支，有 `workout_processed` 先例）

- [ ] **Step 1: 加分支**

```swift
// AppDelegate didReceiveRemoteNotification，既有 notificationType switch 加：
case "deferred_edit_failed":
    // 發 local notification 引導用戶回週回顧重講(深連列 stretch:先純提示)
    presentLocalNotice(title: "課表調整未套用",
                       body: "沒能套用你上週的調整，打開 Rizo 再說一次就好。")
```
> `presentLocalNotice` 若無現成 helper，用 `UNUserNotificationCenter` 包一個；深連回特定週回顧需 UNUserNotificationCenter delegate，列**後續 PR**。

- [ ] **Step 2: Clean build**

Expected: BUILD SUCCEEDED。

- [ ] **Step 3: Commit**

```bash
git add Havital/.../AppDelegate.swift
git commit -m "feat(weekly-review): handle deferred_edit_failed FCM (local notice)"
```

---

### Task 11：Maestro 端到端 + 交付 gate

**Files:**
- Create: `apps/ios/Havital/.maestro/flows/weekly-review-nl-input.yaml`

- [ ] **Step 1: 寫 flow（進週回顧 → 打字 → 送出 → 斷言確認 + pending）**

```yaml
appId: com.havital.Havital
---
- launchApp
# 導航到週回顧(沿用既有 flow 的導航步驟,grep .maestro/flows 既有週回顧 flow)
- tapOn: { id: "weekly_nl_input" }
- inputText: "下週五六爬山不能跑，想多休息"
- tapOn: "送出"
- assertVisible: "已記下"      # pending 狀態文案
```
> 需先給 TextField / 按鈕 accessibilityIdentifier（如 `weekly_nl_input`）。Maestro 前置：HealthKit 已授權、有訓練計畫、語言繁中（見 testing.md）。

- [ ] **Step 2: 跑 flow**

Run: `maestro test .maestro/flows/weekly-review-nl-input.yaml`（**不可** `--no-window`）
Expected: PASS。分類失敗:app bug / script bug / env。

- [ ] **Step 3: 交付 gate**

- [ ] Clean build 通過（iPhone 17 Pro）
- [ ] iOS 單元測試（Mapper + Coordinator）通過
- [ ] 後端 Part A 測試通過（`pytest` Task 1-4）
- [ ] 跑 `/simplify`（iOS delivery 規矩）

- [ ] **Step 4: Commit**

```bash
git add .maestro/flows/weekly-review-nl-input.yaml
git commit -m "test(weekly-review): maestro flow for NL input + pending state"
```

---

## Self-Review（對照 spec）

- **Spec §2 in-scope** → Task 1(驗證)/2(deferred_stored)/3(i18n)/5-9(iOS DTO→View)/10(FCM)：覆蓋。
- **Spec §3 優先序** → Task 4 整合測試：覆蓋。
- **Spec §4.4 DI lazy resolve** → Task 8 Step 3：覆蓋（match 既有 line 97/106 範式）。
- **Spec §6 錯誤處理**（cancelled/空/超長/覆寫/非 plan-change）→ Task 1/8/9：覆蓋（覆寫提示=View 小字；非 plan-change=deferred_stored）。
- **Spec §7 測試** → Task 1/3/4(後端) + 7/8(iOS 單元) + 11(Maestro)：覆蓋。
- **缺口/務實降級**：deferred_stored 的 unit 測點依實際 `_chat_v2` 結構可能改為 endpoint 整合測（Task 2 註已標）；FCM 深連列後續 PR（Task 10）；applied 主動推播為 backlog（不在本 plan）。
- **型別一致**：`UserNlEditStatus`(.none/.pending/.applied/.failed) 在 Entity(T6)/Mapper(T7)/View(T9) 一致；`sendChat(scenario:message:sessionId:)->RizoReply.response` 全程一致。
