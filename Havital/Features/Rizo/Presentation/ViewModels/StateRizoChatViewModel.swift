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
