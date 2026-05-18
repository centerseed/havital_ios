import XCTest
@testable import paceriz_dev

final class PinnedBadgeStorageTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PinnedBadgeStorage.clear()
    }

    override func tearDown() {
        PinnedBadgeStorage.clear()
        super.tearDown()
    }

    func test_load_returnsNil_whenNothingSaved() {
        XCTAssertNil(PinnedBadgeStorage.load())
    }

    func test_save_persistsBadgeId() {
        PinnedBadgeStorage.save("BADGE-BUILD-EIGHT-WEEK-BLOCK")
        XCTAssertEqual(PinnedBadgeStorage.load(), "BADGE-BUILD-EIGHT-WEEK-BLOCK")
    }

    func test_save_nil_unpins() {
        PinnedBadgeStorage.save("BADGE-X")
        PinnedBadgeStorage.save(nil)
        XCTAssertNil(PinnedBadgeStorage.load())
    }

    func test_save_emptyString_unpins() {
        PinnedBadgeStorage.save("BADGE-Z")
        PinnedBadgeStorage.save("")
        XCTAssertNil(PinnedBadgeStorage.load())
    }

    func test_clear_removes() {
        PinnedBadgeStorage.save("BADGE-Y")
        PinnedBadgeStorage.clear()
        XCTAssertNil(PinnedBadgeStorage.load())
    }
}
