import Foundation

@MainActor
final class AnnouncementViewModel: ObservableObject, TaskManageable {

    // MARK: - Published

    @Published var bannerAnnouncement: Announcement?
    @Published var allAnnouncements: [Announcement] = []
    @Published var unreadCount: Int = 0
    @Published var isLoadingBanner: Bool = false
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

    // MARK: - Home Banner

    /// App 啟動後呼叫，載入並顯示最新未讀公告 Banner（AC-ANN-01）
    func loadBannerAnnouncement() {
        Task { [weak self] in
            guard let self else { return }
            await self.executeTask(id: TaskID("load_banner")) { [weak self] in
                guard let self else { return }
                await MainActor.run { self.isLoadingBanner = true }
                defer {
                    Task { @MainActor [weak self] in
                        self?.isLoadingBanner = false
                    }
                }

                let announcements = try await self.repository.fetchAnnouncements()
                let unread = announcements
                    .filter { !$0.isSeen }
                    .sorted { $0.publishedAt > $1.publishedAt }

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.unreadCount = unread.count
                    self.bannerAnnouncement = unread.first
                }

                // Banner 顯示後立刻標記已讀（AC-ANN-02）
                if let banner = unread.first {
                    try await self.repository.markSeen(id: banner.id)
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
