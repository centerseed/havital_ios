import Combine
import Foundation

// MARK: - RizoHistoryViewModel
/// Rizo 過去對話清單（唯讀）。
/// Presentation Layer — 依賴 RizoRepository protocol（絕不依賴 RizoRepositoryImpl）。
/// getHistory() 回攤平 turns → RizoConversationSummary.group 分組 → ViewState。
@MainActor
final class RizoHistoryViewModel: ObservableObject, TaskManageable {

    @Published private(set) var state: ViewState<[RizoConversationSummary]> = .loading

    let taskRegistry = TaskRegistry()

    private let repository: RizoRepository

    /// - Parameter repository: 注入測試替身用；預設由 DependencyContainer 解析。
    init(repository: RizoRepository? = nil) {
        self.repository = repository ?? DependencyContainer.shared.resolve()
    }

    deinit {
        cancelAllTasks()
    }

    /// 載入並分組。取消（主動導航）不進 error（iOS 規範）。
    func load() async {
        state = .loading
        do {
            let items = try await repository.getHistory()
            let conversations = RizoConversationSummary.group(from: items)
            state = conversations.isEmpty ? .empty : .loaded(conversations)
        } catch is CancellationError {
            return
        } catch {
            state = .error(error.toDomainError())
        }
    }
}
