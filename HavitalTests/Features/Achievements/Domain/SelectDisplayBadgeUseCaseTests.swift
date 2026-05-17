import XCTest
@testable import Havital

final class SelectDisplayBadgeUseCaseTests: XCTestCase {
    private let sut = SelectDisplayBadgeUseCase()

    func test_returnsNil_whenAllInputsEmpty() {
        XCTAssertNil(sut.execute(pinnedBadgeId: nil, allBadges: []))
    }

    func test_returnsPinnedBadge_whenPinnedExists() {
        let badges = [makeBadge(id: "A"), makeBadge(id: "B", status: .inProgress)]
        let result = sut.execute(pinnedBadgeId: "A", allBadges: badges)
        XCTAssertEqual(result?.badgeId, "A")
    }

    func test_fallsBackToHighestProgressInProgress_whenNoPin() {
        let badges = [
            makeBadge(id: "FAR", status: .inProgress, progress: 0.10),
            makeBadge(id: "CLOSE", status: .inProgress, progress: 0.85),
            makeBadge(id: "MID", status: .inProgress, progress: 0.50),
        ]
        let result = sut.execute(pinnedBadgeId: nil, allBadges: badges)
        XCTAssertEqual(result?.badgeId, "CLOSE")
    }

    func test_pinnedMissing_fallsBackToAlgorithm() {
        let badges = [makeBadge(id: "ONLY", status: .inProgress, progress: 0.40)]
        let result = sut.execute(pinnedBadgeId: "DELETED-PIN", allBadges: badges)
        XCTAssertEqual(result?.badgeId, "ONLY")
    }

    func test_returnsMostRecentUnlock_whenNoInProgress() {
        let badges = [
            makeBadge(id: "OLD", status: .unlocked, unlockedAt: "2026-01-01T00:00:00Z"),
            makeBadge(id: "NEW", status: .unlocked, unlockedAt: "2026-05-10T00:00:00Z"),
        ]
        let result = sut.execute(pinnedBadgeId: nil, allBadges: badges)
        XCTAssertEqual(result?.badgeId, "NEW")
    }

    func test_returnsFirstBadge_whenAllLockedAndNoInProgress() {
        let badges = [makeBadge(id: "LOCK1", status: .locked), makeBadge(id: "LOCK2", status: .locked)]
        let result = sut.execute(pinnedBadgeId: nil, allBadges: badges)
        XCTAssertNotNil(result)
    }

    // MARK: - Helpers

    private func makeBadge(
        id: String,
        status: AchievementBadgeStatus = .locked,
        progress: Double? = nil,
        unlockedAt: String? = nil
    ) -> AchievementBadge {
        AchievementBadge(
            badgeId: id,
            chapter: .start,
            nameKey: "test.\(id).name",
            storyKey: "test.\(id).story",
            status: status,
            progress: progress.map { AchievementProgress(current: $0, target: 1.0, unitKey: nil, summaryKey: nil, summaryParams: [:]) },
            unlockedAt: unlockedAt,
            unlockReasonKey: nil,
            sourceRef: nil,
            historicalBackfill: false,
            shareable: true,
            assetName: nil
        )
    }
}
