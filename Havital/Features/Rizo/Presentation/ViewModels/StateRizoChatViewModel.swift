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
        let id = UUID()
        let role: Role
        let text: String
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

    private let scenario: String
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
            messages.append(Message(role: .coach, text: Self.appliedText))
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

    private static let appliedText = NSLocalizedString(
        "rizo.plan_change.applied", comment: "已為你套用，課表更新囉")
    private static let confirmFailedText = NSLocalizedString(
        "rizo.plan_change.confirm_failed", comment: "套用失敗，請稍後再試")

    // MARK: - Private

    /// 與後端交換一回合：userText 為 nil 代表開場（送空字串）。
    private func exchange(userText: String?) async {
        isReplying = true
        defer { isReplying = false }
        do {
            let reply = try await repository.sendChat(
                scenario: scenario,
                message: userText ?? "",
                sessionId: sessionId
            )
            sessionId = reply.sessionId
            messages.append(Message(role: .coach, text: reply.reply))
            // 改課表:這一回合若帶待確認提案 → 顯示按鈕(取代上一個未決提案)。
            pendingPlanChange = reply.pendingPlanChange
        } catch is CancellationError {
            // 取消為主動導航，不顯示錯誤（iOS 規範：取消事件不碰 UI 錯誤狀態）。
            return
        } catch {
            messages.append(Message(
                role: .coach,
                text: NSLocalizedString("rizo.chat.error", comment: "Rizo 暫時無法回覆")
            ))
        }
    }
}
