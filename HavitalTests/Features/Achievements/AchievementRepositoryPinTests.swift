import XCTest
import Combine
@testable import paceriz_dev

final class AchievementRepositoryPinTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PinnedBadgeStorage.clear()
        // commit df716dd: DisplayBadgeStorage uses UserDefaults.standard; clear to avoid cross-test leakage.
        DisplayBadgeStorage.clear()
    }

    override func tearDown() {
        PinnedBadgeStorage.clear()
        DisplayBadgeStorage.clear()
        super.tearDown()
    }

    func test_setPinnedBadgeId_persistsAndEmitsChange() {
        let sut = AchievementRepositoryImpl(dataSource: AchievementRemoteDataSource())

        var observed: [String?] = []
        let cancellable = sut.pinnedBadgeIdDidChange.sink { observed.append($0) }
        defer { cancellable.cancel() }

        sut.setPinnedBadgeId("BADGE-X")

        XCTAssertEqual(sut.getPinnedBadgeId(), "BADGE-X")
        XCTAssertEqual(observed.count, 2, "Should receive initial nil emission + the new BADGE-X")
        XCTAssertTrue(observed.first == .some(nil), "CurrentValueSubject should emit current value (nil) on subscribe")
        XCTAssertEqual(observed.last, "BADGE-X")
    }

    func test_getDisplayBadge_returnsNil_whenNoCachedSummary() {
        let sut = AchievementRepositoryImpl(dataSource: AchievementRemoteDataSource())
        XCTAssertNil(sut.getDisplayBadge())
    }

    func test_setPinnedBadgeId_nil_clearsPin() {
        let sut = AchievementRepositoryImpl(dataSource: AchievementRemoteDataSource())
        sut.setPinnedBadgeId("BADGE-X")
        sut.setPinnedBadgeId(nil)

        XCTAssertNil(sut.getPinnedBadgeId())
    }

    func test_getInProgressBadges_returnsEmpty_whenNoCachedSummary() {
        let sut = AchievementRepositoryImpl(dataSource: AchievementRemoteDataSource())
        XCTAssertTrue(sut.getInProgressBadges().isEmpty)
    }

    func test_findBadge_returnsNil_whenNoCachedSummary() {
        let sut = AchievementRepositoryImpl(dataSource: AchievementRemoteDataSource())
        XCTAssertNil(sut.findBadge(byId: "BADGE-X"))
    }

    func test_pinnedBadgeIdDidChange_emitsInitialValue() {
        // Seed a pinned badge before creating the repo
        PinnedBadgeStorage.save("SEED-BADGE")

        let sut = AchievementRepositoryImpl(dataSource: AchievementRemoteDataSource())
        var observed: [String?] = []
        let cancellable = sut.pinnedBadgeIdDidChange.sink { observed.append($0) }
        defer { cancellable.cancel() }

        // CurrentValueSubject emits immediately on subscribe
        XCTAssertEqual(observed.first, "SEED-BADGE")
    }
}
