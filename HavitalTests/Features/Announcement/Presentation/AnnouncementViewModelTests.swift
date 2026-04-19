import XCTest
@testable import paceriz_dev

@MainActor
final class AnnouncementViewModelTests: XCTestCase {
    private var repository: AnnouncementRepositorySpy!
    private var sut: AnnouncementViewModel!

    override func setUp() {
        super.setUp()
        repository = AnnouncementRepositorySpy()
        sut = AnnouncementViewModel(repository: repository)
    }

    override func tearDown() {
        sut = nil
        repository = nil
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
            self.sut.currentPopup?.id == "older"
                && (await self.repository.markSeenIDsSnapshot()).count == 2
        }
        let markSeenIDs = await repository.markSeenIDsSnapshot()

        XCTAssertEqual(markSeenIDs, ["newer", "older"])
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
