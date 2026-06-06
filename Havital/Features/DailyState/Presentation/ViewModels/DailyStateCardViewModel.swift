import Foundation

// MARK: - DailyStateCardViewModel
/// Presentation Layer — 今日狀態卡片 ViewModel。
/// @MainActor + ObservableObject + TaskManageable；依賴 DailyStateRepository protocol（非 Impl）。
@MainActor
final class DailyStateCardViewModel: ObservableObject, TaskManageable {
    @Published private(set) var state: ViewState<DailyStateCard> = .loading

    nonisolated let taskRegistry = TaskRegistry()
    private let repository: DailyStateRepository

    init(repository: DailyStateRepository? = nil) {
        if let repository {
            self.repository = repository
        } else {
            let container = DependencyContainer.shared
            if !container.isRegistered(DailyStateRepository.self) {
                container.registerDailyStateModule()
            }
            self.repository = container.resolve() as DailyStateRepository
        }
    }

    deinit {
        cancelAllTasks()
    }

    /// View 入口（fire-and-forget）。
    func load() {
        Task { [weak self] in await self?.loadForTest() }
    }

    /// 可測 async 入口（View 用 load()；測試直接 await 這支）。
    func loadForTest() async {
        await executeTask(id: TaskID("daily_state_load"), cooldownSeconds: 1) { [weak self] in
            guard let self else { return }
            await MainActor.run {
                if self.state.data == nil { self.state = .loading }
            }
            do {
                let card = try await self.repository.fetchTodayState()
                await MainActor.run { self.state = .loaded(card) }
            } catch let urlError as URLError where urlError.code == .cancelled {
                return
            } catch HTTPError.cancelled {
                return
            } catch {
                await MainActor.run { self.state = .error(error.toDomainError()) }
            }
        }
    }
}
