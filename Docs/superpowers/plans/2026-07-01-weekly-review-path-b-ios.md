# iOS 週回顧接上路徑 B（deferred 改課表）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓 iOS 週回顧畫面能端到端走完後端路徑 B（deferred 改課表）的 propose→confirm→apply，做法是內嵌複用既有 `StateRizoChatViewModel`/`RizoChatView` 多輪對話引擎，拆掉 T-0029 的一次性小框。

**Architecture:** 週回顧 `AdjustmentsSectionV2`（`WeeklySummaryV2View.swift` 內私有 subview）移除舊 NL 一次性小框，改內嵌 `RizoChatView(viewModel: StateRizoChatViewModel(scenario:"weekly_situation"))`（懶載入、不 `startOpening()`）。`StateRizoChatViewModel` 的 confirm 後語意改為依 scenario 決定（`weekly_situation` → 延後語意）。後端零改動。

**Tech Stack:** SwiftUI、`@StateObject`、`@Observable` coordinator、XCTest、Maestro。iOS repo。build target scheme `Havital`（測試 target module `paceriz_dev`）。

**設計 spec:** `docs/superpowers/specs/2026-07-01-weekly-review-path-b-ios-design.md`
**相關 task:** 重定義 [[T-0029-rizo-weekly-review-nl-input-ios]]。

---

## File Structure（改動地圖）

| 檔案 | 動作 | 責任 |
|------|------|------|
| `Havital/Features/Rizo/Presentation/ViewModels/StateRizoChatViewModel.swift` | Modify | confirm 後 applied 文案改依 scenario（延後 vs 即時） |
| `Havital/Resources/{zh-Hant,ja,en}.lproj/Localizable.strings` | Modify | 新增 `rizo.plan_change.applied_deferred` + 內嵌區標題 key；移除只服務舊小框的 `weekly_review.nl_input.*` |
| `Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift` | Modify | `AdjustmentsSectionV2` 移除舊 NL 小框子區塊，改內嵌 `RizoChatView` |
| `Havital/Features/TrainingPlanV2/Presentation/ViewModels/WeeklySummaryCoordinator.swift` | Modify | 移除 `userNlDraft` / `userNlSubmitState` / `submitUserNlEdit()`（改由內嵌對話取代） |
| `HavitalTests/Features/Rizo/StateRizoChatViewModelTests.swift` | Modify | 更新既有 accept 測試（weekly_situation 期望改延後字串）+ 新增 body_status 即時字串測試 |
| `HavitalTests/Features/TrainingPlanV2/Presentation/WeeklySummaryCoordinatorTests.swift` | Modify | 移除引用已刪 NL 成員的測試 |
| `.maestro/flows/weekly-review-nl-input.yaml` | Modify | 改寫成 propose→提案卡→confirm→斷言延後語意 |

**注意：實作前先開隔離 worktree**（見 Execution Handoff）。iOS repo 目前在 `main`。

---

## Task 1: `StateRizoChatViewModel` confirm 後語意依 scenario 決定

**Files:**
- Modify: `Havital/Features/Rizo/Presentation/ViewModels/StateRizoChatViewModel.swift:105,131-132`
- Modify: `Havital/Resources/zh-Hant.lproj/Localizable.strings`、`ja.lproj/Localizable.strings`、`en.lproj/Localizable.strings`
- Test: `HavitalTests/Features/Rizo/StateRizoChatViewModelTests.swift`

- [ ] **Step 1: 更新既有 accept 測試 + 新增 body_status 即時測試（先讓它們失敗）**

既有 `test_accept_success_appends_user_confirmed_bubble_before_coach_applied`（約 line 143）目前用 scenario `weekly_situation` 卻斷言 applied == `rizo.plan_change.applied`。改成期望**延後**字串：

```swift
// 將該測試內這行：
//   let applied = NSLocalizedString("rizo.plan_change.applied", comment: "")
// 改為：
let applied = NSLocalizedString("rizo.plan_change.applied_deferred", comment: "")
```

並在同檔 `// MARK: - #3 user-confirmed bubble` 區塊後，新增一條 body_status 走即時語意的測試：

```swift
func test_accept_success_bodyStatus_uses_immediate_applied_text() async {
    let pending = PendingPlanChange(proposalId: "rpc_2", summary: "x",
                                    safetyLevel: "none", requiresSubscription: false, diffDays: nil)
    let base = makeReply(text: "幫你調輕一點", sessionId: "s1")
    let reply = RizoReply(reply: base.reply, sessionId: base.sessionId,
                          quota: base.quota, safety: base.safety, pendingPlanChange: pending)
    let fake = FakeRizoRepository(reply: reply)
    let vm = StateRizoChatViewModel(scenario: "body_status", repository: fake)
    await vm.startOpening()

    await vm.acceptPlanChange()

    let immediate = NSLocalizedString("rizo.plan_change.applied", comment: "")
    let deferred = NSLocalizedString("rizo.plan_change.applied_deferred", comment: "")
    let texts = vm.messages.map { $0.text }
    XCTAssertTrue(texts.contains(immediate), "body_status 應維持即時語意「已套用」")
    XCTAssertFalse(texts.contains(deferred), "body_status 不應出現延後語意")
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run:
```bash
xcodebuild test -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' \
  -only-testing:HavitalTests/StateRizoChatViewModelTests -parallel-testing-enabled NO
```
Expected: 兩條 accept 測試 FAIL（`applied_deferred` key 尚未存在 → 回 key 原字串，且 VM 仍 append 舊 `applied`）。

- [ ] **Step 3: 實作 — applied 文案改依 scenario**

在 `StateRizoChatViewModel.swift` 移除 `private static let appliedText`（約 line 131-132），改為 instance 計算屬性（放在 `// MARK: - Private` 區）：

```swift
/// confirm 成功後的教練訊息：weekly_situation（路徑 B）延後語意；其餘（body_status）即時語意。
private var appliedText: String {
    scenario == "weekly_situation"
        ? NSLocalizedString("rizo.plan_change.applied_deferred",
                            comment: "已記下，下週生成課表時自動套用")
        : NSLocalizedString("rizo.plan_change.applied",
                            comment: "已為你套用，課表更新囉")
}
```

把 `acceptPlanChange()` 內（約 line 105）：
```swift
messages.append(Message(role: .coach, text: Self.appliedText))
```
改為（instance 屬性，去掉 `Self.`）：
```swift
messages.append(Message(role: .coach, text: appliedText))
```

`confirmFailedText` / `userConfirmedText` 維持 `static let` 不動。

- [ ] **Step 4: 三語系新增 `rizo.plan_change.applied_deferred`**

`Havital/Resources/zh-Hant.lproj/Localizable.strings`：
```
"rizo.plan_change.applied_deferred" = "好，我記下了。下週課表生成時會自動幫你套用這個調整。";
```
`Havital/Resources/ja.lproj/Localizable.strings`：
```
"rizo.plan_change.applied_deferred" = "了解しました。来週のプランを作成するときに、この調整を自動で反映します。";
```
`Havital/Resources/en.lproj/Localizable.strings`：
```
"rizo.plan_change.applied_deferred" = "Got it — I've noted this. It'll be applied automatically when next week's plan is generated.";
```

- [ ] **Step 5: 跑測試確認通過**

Run:
```bash
xcodebuild test -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' \
  -only-testing:HavitalTests/StateRizoChatViewModelTests -parallel-testing-enabled NO
```
Expected: PASS（weekly_situation → 延後字串；body_status → 即時字串；既有其餘測試不受影響）。

- [ ] **Step 6: Commit**

```bash
git add Havital/Features/Rizo/Presentation/ViewModels/StateRizoChatViewModel.swift \
        Havital/Resources/zh-Hant.lproj/Localizable.strings \
        Havital/Resources/ja.lproj/Localizable.strings \
        Havital/Resources/en.lproj/Localizable.strings \
        HavitalTests/Features/Rizo/StateRizoChatViewModelTests.swift
git commit -m "feat(rizo): confirm 後語意依 scenario 分流（weekly_situation 延後 / body_status 即時）"
```

---

## Task 2: Layout spike — `RizoChatView` 內嵌週回顧 ScrollView 的巢狀捲動 + 鍵盤

> spec §5 唯一技術風險。先做最小內嵌驗證，確認捲動不打架、鍵盤彈出時 inputBar 可見，再進 Task 3 正式接線。

**Files:**
- Modify（暫時）: `Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift`（`AdjustmentsSectionV2`）

- [ ] **Step 1: 在 `AdjustmentsSectionV2` 內最小內嵌一個 chatVM + RizoChatView**

在 `AdjustmentsSectionV2`（約 line 909）加：
```swift
@StateObject private var chatVM = StateRizoChatViewModel(scenario: "weekly_situation")
```
在 `body` 內、原 NL 子區塊位置（約 line 959）**暫時**放：
```swift
RizoChatView(viewModel: chatVM)
```

- [ ] **Step 2: Build + 模擬器實跑，觀察巢狀捲動與鍵盤**

Run:
```bash
xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4'
```
用模擬器開到週回顧、聚焦輸入框，人工觀察（截圖）：
- 週回顧外層可正常捲動、內嵌對話不搶捲動手勢卡死。
- 鍵盤彈出時 `RizoChatView` 的 inputBar 仍可見（不被鍵盤蓋掉）。

- [ ] **Step 3: 判定並記錄**

- 若 OK → 保留此內嵌骨架，直接進 Task 3 補齊（懶載入引導文字、移除舊 box）。
- 若巢狀 scroll 卡死無法乾淨解 → **停下回報用戶**，改走 spec §5 fallback（CTA→sheet 開全屏 `RizoChatView`）。此為需用戶確認的方向變更，不自行決定。

- [ ] **Step 4: Commit（spike 骨架）**

```bash
git add Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift
git commit -m "spike(weekly-review): 內嵌 RizoChatView 巢狀捲動/鍵盤驗證"
```

---

## Task 3: 週回顧內嵌對話正式接線（懶載入 + 移除舊 NL 小框 UI）

**Files:**
- Modify: `Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift`（`AdjustmentsSectionV2` line 909-1075 區）
- Modify: `Havital/Resources/{zh-Hant,ja,en}.lproj/Localizable.strings`

- [ ] **Step 1: 移除舊 NL 一次性小框子區塊**

在 `AdjustmentsSectionV2.body` 刪掉 `// MARK: - 自由文字 NL 子區塊（延後改下週課表）` 起、到其外框 `.padding(14).background(...).cornerRadius(...)` 止的整段（約 line 959-1075 那個包含 `weekly_nl_input` / `weekly_nl_submit` / `weekly_nl_reply` / `adjustments.userNlEditStatus` 的 VStack）。同時移除該 subview 頂部不再需要的 `@FocusState private var nlInputFocused`（若無其他使用者）。

- [ ] **Step 2: 換成懶載入內嵌對話（標題 + RizoChatView）**

在同位置放入（`chatVM` 為 Task 2 已加的 `@StateObject`）：
```swift
// MARK: - 跟 Rizo 調整下週課表（路徑 B：延後到下週生成時套用）
VStack(alignment: .leading, spacing: 10) {
    HStack(spacing: 6) {
        Image(systemName: "bubble.left.and.text.bubble.right.fill")
            .font(AppFont.subheadline())
            .foregroundColor(.blue)
        Text(NSLocalizedString("weekly_review.rizo_chat.title", comment: "跟 Rizo 調下週課表"))
            .font(AppFont.subheadline())
            .fontWeight(.semibold)
            .foregroundColor(.primary)
    }
    Text(NSLocalizedString("weekly_review.rizo_chat.hint",
                           comment: "想調整下週課表？直接跟 Rizo 說一句，例如「下週五六爬山不能跑」"))
        .font(AppFont.caption())
        .foregroundColor(.secondary)

    // 懶載入：不呼叫 startOpening()，用戶送第一句才發 chat。
    RizoChatView(viewModel: chatVM)
}
.padding(14)
.background(Color(UIColor.secondarySystemGroupedBackground))
.cornerRadius(14)
```

> 注意：**不要**在 `.onAppear` 呼叫 `chatVM.startOpening()`（與今日卡片 `DailyStateDetailView` 不同，這裡刻意懶載入）。`RizoChatView` 在 messages 為空時只顯 header + inputBar，符合「靜態引導 + 輸入框」。

- [ ] **Step 3: i18n 新增內嵌標題/引導 + 移除只服務舊小框的 key**

三語系各新增 `weekly_review.rizo_chat.title`、`weekly_review.rizo_chat.hint`：

`zh-Hant`：
```
"weekly_review.rizo_chat.title" = "跟 Rizo 調下週課表";
"weekly_review.rizo_chat.hint" = "想調整下週課表？直接跟 Rizo 說一句，例如「下週五六爬山不能跑」。";
```
`ja`：
```
"weekly_review.rizo_chat.title" = "Rizoと来週のプランを調整";
"weekly_review.rizo_chat.hint" = "来週のプランを調整したい？Rizoにひとこと。例：「来週の金土は山でランできない」。";
```
`en`：
```
"weekly_review.rizo_chat.title" = "Adjust next week with Rizo";
"weekly_review.rizo_chat.hint" = "Want to tweak next week's plan? Just tell Rizo, e.g. \"Can't run Fri/Sat next week — hiking.\"";
```

移除三語系中只服務已刪小框的 key（grep 確認全 repo 無其他引用後刪）：`weekly_review.nl_input.title`、`.hint`、`.placeholder`、`.submit`、`.error`、`.status_pending`、`.status_applied`、`.status_failed`。（`weekly_review.deferred_failed.*` 為通知用，**保留**。）

- [ ] **Step 4: Build**

Run:
```bash
xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4'
```
Expected: 成功。若 `WeeklySummaryCoordinator` 的 `userNlDraft`/`submitUserNlEdit` 已無引用而報 unused，於 Task 4 移除。

- [ ] **Step 5: Commit**

```bash
git add Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift \
        Havital/Resources/zh-Hant.lproj/Localizable.strings \
        Havital/Resources/ja.lproj/Localizable.strings \
        Havital/Resources/en.lproj/Localizable.strings
git commit -m "feat(weekly-review): 內嵌 Rizo 多輪對話取代一次性 NL 小框（懶載入）"
```

---

## Task 4: 移除 coordinator 死碼 + 修對應測試

**Files:**
- Modify: `Havital/Features/TrainingPlanV2/Presentation/ViewModels/WeeklySummaryCoordinator.swift`
- Modify: `HavitalTests/Features/TrainingPlanV2/Presentation/WeeklySummaryCoordinatorTests.swift`

- [ ] **Step 1: 找出所有引用點**

Run:
```bash
grep -rn "userNlDraft\|userNlSubmitState\|submitUserNlEdit" \
  Havital/ HavitalTests/ --include="*.swift"
```
Expected: 剩下的引用只在 `WeeklySummaryCoordinator.swift` 定義處 + `WeeklySummaryCoordinatorTests.swift`（View 引用已於 Task 3 移除）。

- [ ] **Step 2: 移除 coordinator 成員**

`WeeklySummaryCoordinator.swift` 刪除：
- `var userNlDraft: String = ""`（約 line 45）
- `var userNlSubmitState: ViewState<String> = .empty`（約 line 47）
- 整個 `submitUserNlEdit()`（約 line 110-127，`// MARK: - Weekly Review NL Edit` 區）
- 若 `rizoRepository` / `injectedRizoRepository` 已無其他使用者則一併移除（先 grep 確認：`grep -n "rizoRepository" WeeklySummaryCoordinator.swift`）；若仍被別處用則保留。

- [ ] **Step 3: 移除/修正對應測試**

`WeeklySummaryCoordinatorTests.swift`：刪掉任何驗 `submitUserNlEdit` / `userNlSubmitState` / `userNlDraft` 的測試 case（grep Step 1 已定位）。其餘測試不動。

- [ ] **Step 4: Build + 跑 coordinator 測試**

Run:
```bash
xcodebuild test -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' \
  -only-testing:HavitalTests/WeeklySummaryCoordinatorTests -parallel-testing-enabled NO
```
Expected: PASS（無殘留對已刪成員的引用）。

- [ ] **Step 5: Commit**

```bash
git add Havital/Features/TrainingPlanV2/Presentation/ViewModels/WeeklySummaryCoordinator.swift \
        HavitalTests/Features/TrainingPlanV2/Presentation/WeeklySummaryCoordinatorTests.swift
git commit -m "refactor(weekly-review): 移除一次性 NL 小框死碼 + 對應測試"
```

---

## Task 5: 改寫 Maestro flow（propose→提案卡→confirm）

**Files:**
- Modify: `.maestro/flows/weekly-review-nl-input.yaml`

- [ ] **Step 1: 讀現有 flow，掌握到達週回顧的前置步驟**

Run:
```bash
cat .maestro/flows/weekly-review-nl-input.yaml
```
記下：登入、到 Plan tab、Debug 產生週回顧的步驟（保留），只改 NL 互動與斷言段。

- [ ] **Step 2: 改互動 — 打字進內嵌對話輸入框**

舊 flow 用 `weekly_nl_input` / `weekly_nl_submit` / `weekly_nl_reply` id（已隨小框刪除）。改用 `RizoChatView` 的輸入元件。先確認 `RizoChatView.inputBar` 的送出可觸發方式（無專屬 id 則用 `inputText` + tap 送出鈕 label；必要時在 `RizoChatView` inputBar 補 `accessibilityIdentifier("rizo_chat_input")` / `("rizo_chat_send")` 再對齊 flow）。範例骨架：

```yaml
- tapOn:
    id: "rizo_chat_input"
- inputText: "下週五六爬山不能跑，想多休息"
- tapOn:
    id: "weekly_nl_keyboard_done"   # 若沿用 RizoChatView 收鍵盤鈕；否則改對應 id
- tapOn:
    id: "rizo_chat_send"
- assertVisible:
    text: ".*"                       # 等 Rizo 回覆/提案卡出現
```

- [ ] **Step 3: 斷言提案卡 + confirm + 延後語意**

```yaml
# 提案卡出現（RizoChatView.planChangeCard 的接受鈕 id 為 rizo_plan_change_accept）
- assertVisible:
    id: "rizo_plan_change_accept"
- tapOn:
    id: "rizo_plan_change_accept"
# confirm 後教練回延後語意（en locale 對照 applied_deferred）
- assertVisible:
    text: "Got it.*generated.*"
```

> 若 accept 鈕 id 與實際不符，以 `RizoChatView.planChangeCard` 內 `.accessibilityIdentifier` 為準對齊（原今日卡片用 `rizo_plan_change_accept`）。

- [ ] **Step 4: 對 dev 後端 live 跑（需 dev 帳號 + 已生成本週回顧）**

Run（**不可加 `--no-window`**）:
```bash
maestro --device BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4 test .maestro/flows/weekly-review-nl-input.yaml
```
Expected: 打字→提案卡→接受→延後語意回覆，flow PASS。

- [ ] **Step 5: Commit**

```bash
git add .maestro/flows/weekly-review-nl-input.yaml \
        Havital/Features/Rizo/Presentation/Views/RizoChatView.swift
git commit -m "test(weekly-review): Maestro flow 改 propose→提案卡→confirm 路徑 B"
```

---

## Task 6: 全量驗收 + delivery gate

- [ ] **Step 1: Clean build（delivery gate）**

Run:
```bash
xcodebuild clean build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: 零錯誤。

- [ ] **Step 2: 跑受影響單元測試**

Run:
```bash
xcodebuild test -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' \
  -only-testing:HavitalTests/StateRizoChatViewModelTests \
  -only-testing:HavitalTests/WeeklySummaryCoordinatorTests -parallel-testing-enabled NO
```
Expected: 全 PASS。

- [ ] **Step 3: 驗收標準逐條核對（spec §7）**

人工於模擬器 + dev 後端核對 spec §7 的 1-7：多輪對話、confirm 延後語意、懶載入（進週回顧無 chat network、送第一句才有）、路徑 A 零回歸（今日卡片仍「已套用」）、付費牆、Maestro live、build 綠、三語 key 齊。每條附證據（截圖 / network log / 測試輸出），不可空宣稱 PASS。

- [ ] **Step 4: `/simplify`**

交付後跑 `/simplify` 清理本批改動（delivery rule 必做）。

- [ ] **Step 5: 更新 T-0029 + inflight manifest（回報用戶後）**

- `STATUS/tasks/T-0029-rizo-weekly-review-nl-input-ios.md`：稽核軌跡補一行指向本 spec/plan + 時序落差說明；狀態視驗收結果調整。
- `STATUS/inflight.manifest.json`：確認 `item_slug: weekly-review-deferred-nl-edit`（iOS probe）在列。
- （動 STATUS 檔前先回報用戶。）

---

## Self-Review（對 spec 逐節核對）

- **spec §4①（內嵌對話 + 移除舊小框 + 懶載入）** → Task 2（spike）+ Task 3（正式接線）+ Task 4（coordinator 死碼）。✅
- **spec §4②（延後語意）** → Task 1。✅（且抓出既有測試需同步改）
- **spec §4③（提案卡/反提案/不支援 iOS 零特別處理）** → 複用 `RizoChatView.planChangeCard` + `StateRizoChatViewModel`，無新任務（設計即免費拿到）；Task 5 斷言提案卡驗證此路。✅
- **spec §4④（deferred_edit_failed 通知保留）** → 不動，無任務（正確：已就緒）。✅
- **spec §5（巢狀捲動風險 + fallback）** → Task 2 spike + Step 3 判定/回報 gate。✅
- **spec §6（YAGNI：不做 applied 狀態顯示）** → Task 3 Step 1/3 移除 `userNlEditStatus` 顯示 + 相關 key。✅
- **spec §7（驗收）** → Task 6。✅
- **spec §8（T-0029 關係）** → Task 6 Step 5。✅

**型別/命名一致性**：`chatVM`（Task 2 定義，Task 3 使用）、`appliedText`（Task 1 instance 屬性）、`weekly_review.rizo_chat.{title,hint}` + `rizo.plan_change.applied_deferred`（Task 1/3 一致）。無前後不一。

**Placeholder 掃描**：各 code 步驟均附實際碼；Maestro id 有「若不符以實際 `.accessibilityIdentifier` 為準」的對齊指示（因 `RizoChatView` inputBar 可能需補 id，Task 5 Step 2 已納入）。無 TBD/TODO。
