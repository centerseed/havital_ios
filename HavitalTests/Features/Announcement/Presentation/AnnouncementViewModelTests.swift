import XCTest
@testable import paceriz_dev

@MainActor
final class AnnouncementViewModelTests: XCTestCase {
    private var repository: AnnouncementRepositorySpy!
    private var sut: AnnouncementViewModel!
    private var interruptCoordinator: InterruptCoordinator!

    override func setUp() {
        super.setUp()
        repository = AnnouncementRepositorySpy()
        interruptCoordinator = InterruptCoordinator()
        sut = AnnouncementViewModel(
            repository: repository,
            interruptCoordinator: interruptCoordinator
        )
    }

    override func tearDown() {
        sut = nil
        repository = nil
        interruptCoordinator = nil
        super.tearDown()
    }

    func testLoadAnnouncementsIfNeededPresentsNewestUnreadPopupAndMarksSeen() async {
        await repository.setAnnouncements([
            makeAnnouncement(id: "older", publishedAt: date(offset: -200), isSeen: false),
            makeAnnouncement(id: "newer", publishedAt: date(offset: -100), isSeen: false),
            makeAnnouncement(id: "seen", publishedAt: date(offset: -50), isSeen: true)
        ])

        sut.loadAnnouncementsIfNeeded()
        await waitUntil { self.sut.currentPopup?.id == "newer" }
        let markSeenIDs = await repository.markSeenIDsSnapshot()

        XCTAssertEqual(sut.unreadCount, 1)
        XCTAssertEqual(markSeenIDs, ["newer"])
    }

    func testDismissCurrentPopupAdvancesToNextPopupInQueue() async {
        await repository.setAnnouncements([
            makeAnnouncement(id: "older", publishedAt: date(offset: -200), isSeen: false),
            makeAnnouncement(id: "newer", publishedAt: date(offset: -100), isSeen: false)
        ])

        sut.loadAnnouncementsIfNeeded()
        await waitUntil { self.sut.currentPopup?.id == "newer" }

        sut.dismissCurrentPopup()
        await waitUntil {
            let markSeenIDs = await self.repository.markSeenIDsSnapshot()
            return self.sut.currentPopup?.id == "older" && markSeenIDs.count == 2
        }
        let markSeenIDs = await repository.markSeenIDsSnapshot()

        XCTAssertEqual(markSeenIDs, ["newer", "older"])
    }

    /// Regression: 冷啟動當下沒有未讀公告時不應鎖死本 session 的 popup，
    /// 之後再次 loadAnnouncementsIfNeeded 拿到新公告時 popup 仍要能彈出。
    func testLoadAnnouncementsIfNeededPresentsPopupWhenFirstLoadHasNoUnread() async {
        await repository.setAnnouncements([
            makeAnnouncement(id: "seen-only", publishedAt: date(offset: -100), isSeen: true)
        ])

        sut.loadAnnouncementsIfNeeded()
        await waitUntil { self.sut.unreadCount == 0 }
        XCTAssertNil(sut.currentPopup)

        // 新公告發出後，再次觸發 load（模擬 scenePhase 回到 active）
        await repository.setAnnouncements([
            makeAnnouncement(id: "seen-only", publishedAt: date(offset: -100), isSeen: true),
            makeAnnouncement(id: "fresh", publishedAt: date(offset: -10), isSeen: false)
        ])

        sut.loadAnnouncementsIfNeeded()
        await waitUntil { self.sut.currentPopup?.id == "fresh" }
        let markSeenIDs = await repository.markSeenIDsSnapshot()

        XCTAssertEqual(markSeenIDs, ["fresh"])
    }

    func testLoadMessageCenterSortsItemsAndMarksUnreadBatchSeen() async {
        await repository.setAnnouncements([
            makeAnnouncement(id: "older-unread", publishedAt: date(offset: -300), isSeen: false),
            makeAnnouncement(id: "middle-seen", publishedAt: date(offset: -200), isSeen: true),
            makeAnnouncement(id: "newer-unread", publishedAt: date(offset: -100), isSeen: false)
        ])

        sut.loadMessageCenter()
        await waitUntil {
            self.sut.allAnnouncements.count == 3
                && self.sut.unreadCount == 0
                && self.sut.allAnnouncements.allSatisfy(\.isSeen)
        }
        let markSeenBatchCalls = await repository.markSeenBatchCallsSnapshot()

        XCTAssertEqual(sut.allAnnouncements.map(\.id), ["newer-unread", "middle-seen", "older-unread"])
        XCTAssertEqual(markSeenBatchCalls, [["older-unread", "newer-unread"]])
    }

    private func waitUntil(
        timeout: TimeInterval = 1.5,
        pollInterval: UInt64 = 50_000_000,
        condition: @escaping @MainActor () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() {
                return
            }
            try? await Task.sleep(nanoseconds: pollInterval)
        }

        XCTFail("Timed out waiting for condition")
    }

    private func makeAnnouncement(
        id: String,
        publishedAt: Date,
        expiresAt: Date? = nil,
        isSeen: Bool
    ) -> Announcement {
        Announcement(
            id: id,
            title: id,
            body: "body",
            imageUrl: nil,
            ctaLabel: nil,
            ctaUrl: nil,
            publishedAt: publishedAt,
            expiresAt: expiresAt,
            isSeen: isSeen
        )
    }

    private func date(offset: TimeInterval) -> Date {
        Date().addingTimeInterval(offset)
    }
}

private actor AnnouncementRepositorySpy: AnnouncementRepository {
    private var announcements: [Announcement] = []
    private var fetchError: Error?
    private var markSeenIDs: [String] = []
    private var markSeenBatchCalls: [[String]] = []

    func setAnnouncements(_ announcements: [Announcement]) {
        self.announcements = announcements
    }

    func fetchAnnouncements() async throws -> [Announcement] {
        if let fetchError {
            throw fetchError
        }
        return announcements
    }

    func markSeen(id: String) async throws {
        markSeenIDs.append(id)
    }

    func markSeenBatch(ids: [String]) async throws {
        markSeenBatchCalls.append(ids)
    }

    func markSeenIDsSnapshot() -> [String] {
        markSeenIDs
    }

    func markSeenBatchCallsSnapshot() -> [[String]] {
        markSeenBatchCalls
    }
}
