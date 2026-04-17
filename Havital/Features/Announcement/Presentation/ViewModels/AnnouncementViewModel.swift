import Foundation

@MainActor
final class AnnouncementViewModel: ObservableObject, TaskManageable {

    // MARK: - Published

    @Published var allAnnouncements: [Announcement] = []
    @Published var unreadCount: Int = 0
    @Published var isLoadingCenter: Bool = false

    // MARK: - TaskManageable

    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Dependencies

    private let repository: AnnouncementRepository

    // MARK: - Init

    init(repository: AnnouncementRepository) {
        self.repository = repository
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Unread Count

    /// App 啟動後呼叫，只計算未讀數量供 toolbar bell badge 使用。
    /// 不自動 markSeen — 使用者進入訊息中心時才批次標已讀（見 loadMessageCenter）。
    func loadUnreadCount() {
        Task { [weak self] in
            guard let self else { return }
            await self.executeTask(id: TaskID("load_unread_count")) { [weak self] in
                guard let self else { return }
                let announcements = try await self.repository.fetchAnnouncements()
                let unread = announcements.filter { !$0.isSeen }.count
                await MainActor.run { [weak self] in
                    self?.unreadCount = unread
                }
            }
        }
    }

    // MARK: - Message Center

    /// 進入訊息中心時呼叫，載入全部公告並批次標記已讀（AC-ANN-05）
    func loadMessageCenter() {
        Task { [weak self] in
            guard let self else { return }
            await self.executeTask(id: TaskID("load_message_center")) { [weak self] in
                guard let self else { return }
                await MainActor.run { self.isLoadingCenter = true }
                defer {
                    Task { @MainActor [weak self] in
                        self?.isLoadingCenter = false
                    }
                }

                let announcements = try await self.repository.fetchAnnouncements()
                let sorted = announcements.sorted { $0.publishedAt > $1.publishedAt }

                await MainActor.run { [weak self] in
                    self?.allAnnouncements = sorted
                }

                // 批次標記所有未讀（AC-ANN-05）
                let unreadIds = announcements.filter { !$0.isSeen }.map { $0.id }
                if !unreadIds.isEmpty {
                    try await self.repository.markSeenBatch(ids: unreadIds)
                    await MainActor.run { [weak self] in
                        self?.unreadCount = 0
                    }
                }
            }
        }
    }
}
