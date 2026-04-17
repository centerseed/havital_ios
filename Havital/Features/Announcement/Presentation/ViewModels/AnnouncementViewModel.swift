import Foundation
import UIKit

@MainActor
final class AnnouncementViewModel: ObservableObject, TaskManageable {

    // MARK: - Published

    @Published var allAnnouncements: [Announcement] = []
    @Published var unreadCount: Int = 0
    @Published var isLoadingCenter: Bool = false
    @Published var currentPopup: Announcement?

    // MARK: - TaskManageable

    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Dependencies

    private let repository: AnnouncementRepository

    // MARK: - Session State

    private var popupQueue: [Announcement] = []
    private var hasLoadedPopupThisSession: Bool = false

    // MARK: - Init

    init(repository: AnnouncementRepository) {
        self.repository = repository
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Load

    /// 合併原 loadUnreadCount 行為：一次抓全量 announcements，同時更新 badge 與 popup queue。
    /// 首次呼叫時建立 popup queue 並自動顯示第一則；後續呼叫只刷新 unreadCount。
    func loadAnnouncementsIfNeeded() {
        Task { [weak self] in
            guard let self else { return }
            await self.executeTask(id: TaskID("load_announcements")) { [weak self] in
                guard let self else { return }
                let announcements = try await self.repository.fetchAnnouncements()
                let unread = announcements.filter { !$0.isSeen }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.unreadCount = unread.count
                    if !self.hasLoadedPopupThisSession {
                        self.hasLoadedPopupThisSession = true
                        self.buildPopupQueue(from: unread)
                        self.presentNextPopup()
                    }
                }
            }
        }
    }

    /// App 啟動後呼叫，只計算未讀數量供 toolbar bell badge 使用。
    /// Deprecated: 保留為相容介面，內部轉呼叫 loadAnnouncementsIfNeeded。
    func loadUnreadCount() {
        loadAnnouncementsIfNeeded()
    }

    // MARK: - Popup

    private func buildPopupQueue(from unread: [Announcement]) {
        let now = Date()
        popupQueue = unread
            .filter { announcement in
                if let expires = announcement.expiresAt {
                    return expires > now
                }
                return true
            }
            .sorted { $0.publishedAt > $1.publishedAt }
            .prefix(AnnouncementPopupPolicy.maxPerSession)
            .map { $0 }
    }

    func presentNextPopup() {
        guard currentPopup == nil, !popupQueue.isEmpty else { return }
        let next = popupQueue.removeFirst()
        currentPopup = next
        unreadCount = max(0, unreadCount - 1)

        let id = next.id
        Task { [weak self] in
            guard let self else { return }
            await self.executeTask(id: TaskID("mark_seen_popup_\(id)")) { [weak self] in
                guard let self else { return }
                do {
                    try await self.repository.markSeen(id: id)
                } catch {
                    Logger.error("[AnnouncementVM] markSeen popup failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func dismissCurrentPopup() {
        currentPopup = nil
        if !popupQueue.isEmpty {
            presentNextPopup()
        }
    }

    func handlePopupCTA(_ announcement: Announcement) {
        if let urlString = announcement.ctaUrl, let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
        dismissCurrentPopup()
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
                    let seenSet = Set(unreadIds)
                    let updated = sorted.map { announcement -> Announcement in
                        guard seenSet.contains(announcement.id) else { return announcement }
                        return Announcement(
                            id: announcement.id,
                            title: announcement.title,
                            body: announcement.body,
                            imageUrl: announcement.imageUrl,
                            ctaLabel: announcement.ctaLabel,
                            ctaUrl: announcement.ctaUrl,
                            publishedAt: announcement.publishedAt,
                            expiresAt: announcement.expiresAt,
                            isSeen: true
                        )
                    }
                    await MainActor.run { [weak self] in
                        self?.allAnnouncements = updated
                        self?.unreadCount = 0
                    }
                }
            }
        }
    }
}
