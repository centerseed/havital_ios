import Combine
import Foundation

// MARK: - StateRizoChatViewModel
/// 今日卡片詳細頁的 Rizo 多輪對話 ViewModel（卡片=Rizo hub）。
/// Presentation Layer - 依賴 RizoRepository protocol（絕不依賴 RizoRepositoryImpl）。
///
/// 開場：`startOpening()` 送空 message + scenario，由後端依 scenario 注入今日狀態生成開場白。
/// 多輪：`send(_:)` 追加用戶訊息、沿用上一回合 sessionId 維持脈絡。
///
/// Rizo 後端在 dev 尚未部署，本批以 protocol + Fake 驗多輪邏輯（見 StateRizoChatViewModelTests）。
@MainActor
final class StateRizoChatViewModel: ObservableObject, TaskManageable {

    // MARK: - Message Model

    /// 對話訊息角色。
    enum Role {
        case coach
        case user
    }

    /// 單則對話訊息（UI 渲染用）。
    struct Message: Identifiable {
        let id: UUID
        let role: Role
        let text: String

        init(id: UUID = UUID(), role: Role, text: String) {
            self.id = id
            self.role = role
            self.text = text
        }
    }

    // MARK: - Published State

    @Published private(set) var messages: [Message] = []
    @Published private(set) var isReplying = false
    @Published var draft: String = ""

    /// 改課表:此 session 目前待確認的提案（教練提出後出現「接受 / 繼續討論」）；無則 nil。
    @Published private(set) var pendingPlanChange: PendingPlanChange?

    /// 正在送出「接受」確認中（避免重複點擊）。
    @Published private(set) var isConfirmingPlanChange = false

    /// 免費用戶按「接受」被 gate → 觸發付費牆（View 觀察後呈現）。
    @Published var paywallTrigger: PaywallTrigger?

    // MARK: - TaskManageable

    let taskRegistry = TaskRegistry()

    // MARK: - Dependencies

    private var scenario: String
    private let repository: RizoRepository
    private var sessionId: String?

    /// 「這段對話換過幾次身分」。`restoreTodaySession` 在等 history 的那段時間裡，
    /// 輸入列與「新對話」鈕都是可以按的（`@MainActor` 允許在 `await` 期間重入），
    /// 所以它回來之後不能只看 `messages.isEmpty` —— 使用者在這中間送出的訊息或
    /// 開的新對話，都必須贏過那份已經過期的還原。
    private var conversationEpoch = 0

    /// 後端對今日卡情境（`body_status`／`weekly_situation`）的每-session 軟上限
    /// ——`cloud/api_service/application/rizo.py` 的 `_SESSION_SOFT_CAP`。到了那個
    /// 輪數，那一段就只會回罐頭收尾，不再進教練模型。
    ///
    /// 改動前 sheet 每次開都是新的 session，這個上限實質上碰不到；帶回當日 session
    /// 之後，同一天所有開啟共用同一份預算。所以**已經用完的那一段不還原**，
    /// 開一段新的——使用者不會因為「帶回上次對話」而卡在收尾語。
    ///
    /// 數字的 SSOT 在後端，這裡是保守的下界：後端調小才需要跟著改，調大不影響正確性。
    private static let sessionSoftCapTurns = 20

    // MARK: - Initialization

    /// - Parameters:
    ///   - scenario: 對話情境（如 "weekly_situation" / "body_status"），對齊 card.rizoScenario。
    ///   - repository: 注入測試替身用；預設由 DependencyContainer 解析 RizoRepository。
    init(scenario: String, repository: RizoRepository? = nil) {
        self.scenario = scenario
        self.repository = repository ?? DependencyContainer.shared.resolve()
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Public API

    /// 教練先開口：送空 message → 後端依 scenario 注入今日狀態生成開場白。
    /// 已有訊息時為 no-op（避免重複開場）。
    func startOpening() async {
        guard messages.isEmpty else { return }
        await exchange(userText: nil)
    }

    /// 用**本機組好的**開場白起頭，不打後端。
    ///
    /// 2.0 首頁的 Rizo sheet（設計 frame-00d）帶著 context 進來（今日建議／今日課表），
    /// 開場白就是那段 context 加一句引導 —— 句子在畫面上已經有了，再叫 LLM 生一次
    /// 只是多一次 latency 與一次不一定講一樣的話。真正的對話從使用者第一句開始，
    /// 之後全部走 `send(_:)`（既有 API），不是第二套對話。
    ///
    /// 已有訊息時為 no-op，與 `startOpening()` 一致。
    func seedOpening(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard messages.isEmpty, !trimmed.isEmpty else { return }
        messages.append(Message(role: .coach, text: trimmed))
    }

    /// 送出一則用戶訊息並等待教練回覆。
    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        conversationEpoch += 1
        messages.append(Message(role: .user, text: trimmed))
        draft = ""
        await exchange(userText: trimmed)
    }

    /// 開 sheet 時把「今天那一段對話」帶回來（T-0434）。
    ///
    /// 使用者 2026-09-05：「今日卡片的 rizo，我聊完之後退出，還想再看剛剛聊什麼就
    /// 看不到了。」以前 sheet 每次開都是全新的 `sessionId=nil`，關掉就沒了。
    ///
    /// 判準是**同一個使用者當地日**。票面寫的是「該 session 第一輪的時間 ≥ 今日卡的
    /// 產生時間」，而 `/v2/state/today` 的回應沒有帶生成時間（`StateCardDTO` 沒有那一欄），
    /// 所以走票面允許的那個 fallback：跨到新的一天就是新的卡片，開空白對話。
    ///
    /// 帶回來的是 history 上最新的那一個 session，續聊沿用它的 `sessionId`——同一段
    /// 對話，不是把舊訊息重送一次，所以不重複扣額度也不重跑任何動作。
    /// 讀不到歷史就當作沒有可帶回的（訓練流程 fail-open）；已經有訊息時是 no-op。
    @discardableResult
    func restoreTodaySession(
        now: Date = Date(), calendar: Calendar = .current
    ) async -> Bool {
        guard messages.isEmpty else { return false }
        let epoch = conversationEpoch
        let items: [RizoHistoryItem]
        let pendingBySession: [String: PendingPlanChange]
        do {
            let history = try await repository.getHistory()
            items = history.items
            pendingBySession = history.pendingPlanChanges
        } catch is CancellationError {
            return false
        } catch {
            return false
        }
        // 等 history 的期間使用者可能已經開口，或按了「新對話」。那兩件事都比這份
        // 還原新，還原不得蓋掉它們。
        guard epoch == conversationEpoch, messages.isEmpty else { return false }
        guard let latest = RizoConversationSummary.group(from: items).first,
              latest.turnCount < Self.sessionSoftCapTurns,
              let firstTurn = latest.turns.first,
              let startedAt = RizoHistoryDateFormatter.date(firstTurn.ts),
              calendar.isDate(startedAt, inSameDayAs: now)
        else { return false }
        let rendered = Self.messages(from: latest.turns)
        guard !rendered.isEmpty else { return false }
        // **不改寫 scenario。** `GET /v2/agent/history` 不分 scenario 回全部輪次，
        // 最新那一段可能來自別的入口（週回顧的 `weekly_situation`）。sheet 的 scenario
        // 是入口自己的身分（`card.rizoScenario`），AC-TRAIN-HUB-13 只授權「畫回來並
        // 沿用它的 session_id」，沒有授權讓歷史接管入口的身分。
        sessionId = latest.sessionId
        messages = rendered
        pendingPlanChange = pendingBySession[latest.sessionId]
        return true
    }

    /// 「新對話」：清空、忘掉 session、回到可以重新開場的狀態（T-0434）。
    /// 送出下一句時 `sessionId` 是 nil，後端就會開一個新的 session。
    func startNewConversation() {
        cancelAllTasks()
        conversationEpoch += 1
        sessionId = nil
        pendingPlanChange = nil
        isConfirmingPlanChange = false
        isReplying = false
        draft = ""
        messages = []
    }

    /// 歷史輪次 → 畫面上的泡泡。`resumeFromHistory` 與 `restoreTodaySession`
    /// 用同一份，兩邊各寫一次就會長出兩種渲染。
    private static func messages(from turns: [RizoHistoryItem]) -> [Message] {
        turns.flatMap { turn -> [Message] in
            var rendered: [Message] = []
            let user = turn.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let coach = turn.rizoResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            if !user.isEmpty { rendered.append(Message(role: .user, text: user)) }
            if !coach.isEmpty { rendered.append(Message(role: .coach, text: coach)) }
            return rendered
        }
    }

    /// 把後端建立完成的 fork 載入目前聊天室。只切換到新的 session id，並用後端
    /// 回傳的 prefix 畫出上下文；不重新送出任何舊訊息，因此不重複扣額度或觸發動作。
    func resumeFromHistory(_ fork: RizoHistoryFork) {
        cancelAllTasks()
        conversationEpoch += 1
        scenario = fork.scenario
        sessionId = fork.sessionId
        pendingPlanChange = nil
        isConfirmingPlanChange = false
        isReplying = false
        draft = ""
        messages = Self.messages(from: fork.turns)
    }

    // MARK: - Plan Change

    /// 使用者按「接受」→ 確認套用待確認的改課表提案。
    /// 成功:清掉按鈕 + 加一則已套用訊息 + 發布課表變更事件讓課表頁 re-pull。
    /// 免費用戶被 gate(訂閱）→ 觸發付費牆。其餘錯誤:加一則失敗訊息、保留提案可重試。
    func acceptPlanChange() async {
        guard let pending = pendingPlanChange, !isConfirmingPlanChange else { return }
        isConfirmingPlanChange = true
        defer { isConfirmingPlanChange = false }
        do {
            let result = try await repository.confirmPlanChange(proposalId: pending.proposalId)
            guard result.applied else {
                messages.append(Message(role: .coach, text: Self.confirmFailedText))
                return
            }
            pendingPlanChange = nil
            // #3:接受成功才 append 用戶側確認泡泡（失敗路徑絕不出現，避免對話說謊）。
            messages.append(Message(role: .user, text: Self.userConfirmedText))
            messages.append(Message(role: .coach, text: appliedText))
            // 課表已變 → 通知課表頁刷新（ViewModel 可發布事件；Repository 不行）。
            CacheEventBus.shared.publish(.dataChanged(.trainingPlanV2))
        } catch is CancellationError {
            return
        } catch {
            if Self.isSubscriptionError(error) {
                paywallTrigger = .apiGated   // 免費用戶被 gate → 付費牆
            } else {
                messages.append(Message(role: .coach, text: Self.confirmFailedText))
            }
        }
    }

    /// 訂閱被 gate 的錯誤(HTTPError 或已映射的 DomainError 皆涵蓋)。
    private static func isSubscriptionError(_ error: Error) -> Bool {
        if let http = error as? HTTPError, case .subscriptionRequired = http { return true }
        if let domain = error as? DomainError, case .subscriptionRequired = domain { return true }
        return false
    }

    /// 使用者按「繼續討論」→ 收起按鈕，繼續對話（提案留在後端，下次提案自動取代）。
    func dismissPlanChange() {
        pendingPlanChange = nil
    }

    /// confirm 成功後的教練訊息：weekly_situation（路徑 B）延後語意；其餘（body_status）即時語意。
    private var appliedText: String {
        scenario == "weekly_situation"
            ? NSLocalizedString("rizo.plan_change.applied_deferred",
                                comment: "已記下，下週生成課表時自動套用")
            : NSLocalizedString("rizo.plan_change.applied",
                                comment: "已為你套用，課表更新囉")
    }
    private static let confirmFailedText = NSLocalizedString(
        "rizo.plan_change.confirm_failed", comment: "套用失敗，請稍後再試")
    private static let userConfirmedText = NSLocalizedString(
        "rizo.plan_change.user_confirmed", comment: "已確認課表更新")

    // MARK: - Private

    /// 與後端交換一回合：userText 為 nil 代表開場（送空字串）。
    ///
    /// **每一次寫回畫面都要先確認這一輪還屬於當下這段對話。**
    /// `startNewConversation()` 呼叫的 `cancelAllTasks()` 取消不到這一輪——送出是
    /// `RizoChatView` 裡沒有註冊進 `taskRegistry` 的 `Task { await viewModel.send(...) }`，
    /// 而 header 那三顆鈕在回覆進行中仍可按。沒有這道檢查的話，回覆落地時
    /// `.partial` 會把泡泡 append 進剛清空的對話、`.final` 會把 `sessionId` 設回舊
    /// session——「新對話」看起來有反應，實際上又接回去了，連
    /// `STATUS/decisions.md` 2026-09-06「T-0434 免費額度口徑」倚賴的脫離方式都會靜默失效。
    private func exchange(userText: String?) async {
        let epoch = conversationEpoch
        isReplying = true
        // 已經不是這一段對話了就不要動它的 `isReplying`——那是新的一輪在用的。
        defer { if epoch == conversationEpoch { isReplying = false } }
        var streamingMessageId: UUID?
        do {
            for try await update in repository.streamChat(
                scenario: scenario,
                message: userText ?? "",
                sessionId: sessionId
            ) {
                guard epoch == conversationEpoch else { return }
                switch update {
                case .partial(let text):
                    if let id = streamingMessageId, let index = messages.firstIndex(where: { $0.id == id }) {
                        messages[index] = Message(id: id, role: .coach, text: text)
                    } else {
                        guard !text.isEmpty else { continue }
                        let message = Message(role: .coach, text: text)
                        streamingMessageId = message.id
                        messages.append(message)
                    }
                case .final(let reply):
                    if let id = streamingMessageId, let index = messages.firstIndex(where: { $0.id == id }) {
                        messages[index] = Message(id: id, role: .coach, text: reply.reply)
                    } else { messages.append(Message(role: .coach, text: reply.reply)) }
                    sessionId = reply.sessionId
                    pendingPlanChange = reply.pendingPlanChange
                    if reply.planChangeApplied {
                        CacheEventBus.shared.publish(.dataChanged(.trainingPlanV2))
                    }
                }
            }
        } catch is CancellationError {
            // 取消為主動導航，不顯示錯誤（iOS 規範：取消事件不碰 UI 錯誤狀態）。
            return
        } catch {
            guard epoch == conversationEpoch else { return }
            if let id = streamingMessageId { messages.removeAll { $0.id == id } }
            messages.append(Message(
                role: .coach,
                text: NSLocalizedString("rizo.chat.error", comment: "Rizo 暫時無法回覆")
            ))
        }
    }
}
