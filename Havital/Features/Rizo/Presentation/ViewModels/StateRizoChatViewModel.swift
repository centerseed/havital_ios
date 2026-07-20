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

    /// 送出一則用戶訊息並等待教練回覆。
    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(Message(role: .user, text: trimmed))
        draft = ""
        await exchange(userText: trimmed)
    }

    /// 把後端建立完成的 fork 載入目前聊天室。只切換到新的 session id，並用後端
    /// 回傳的 prefix 畫出上下文；不重新送出任何舊訊息，因此不重複扣額度或觸發動作。
    func resumeFromHistory(_ fork: RizoHistoryFork) {
        cancelAllTasks()
        scenario = fork.scenario
        sessionId = fork.sessionId
        pendingPlanChange = nil
        isConfirmingPlanChange = false
        isReplying = false
        draft = ""
        messages = fork.turns.flatMap { turn -> [Message] in
            var rendered: [Message] = []
            let user = turn.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let coach = turn.rizoResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            if !user.isEmpty { rendered.append(Message(role: .user, text: user)) }
            if !coach.isEmpty { rendered.append(Message(role: .coach, text: coach)) }
            return rendered
        }
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
    private func exchange(userText: String?) async {
        isReplying = true
        defer { isReplying = false }
        var streamingMessageId: UUID?
        do {
            for try await update in repository.streamChat(
                scenario: scenario,
                message: userText ?? "",
                sessionId: sessionId
            ) {
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
                }
            }
        } catch is CancellationError {
            // 取消為主動導航，不顯示錯誤（iOS 規範：取消事件不碰 UI 錯誤狀態）。
            return
        } catch {
            if let id = streamingMessageId { messages.removeAll { $0.id == id } }
            messages.append(Message(
                role: .coach,
                text: NSLocalizedString("rizo.chat.error", comment: "Rizo 暫時無法回覆")
            ))
        }
    }
}
