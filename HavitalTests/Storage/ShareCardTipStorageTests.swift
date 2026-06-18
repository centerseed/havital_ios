import XCTest
@testable import paceriz_dev

final class ShareCardTipStorageTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ShareCardTipStorage.reset()
    }

    override func tearDown() {
        ShareCardTipStorage.reset()
        super.tearDown()
    }

    func test_shouldShow_trueInitially() {
        XCTAssertTrue(ShareCardTipStorage.shouldShow())
    }

    func test_shouldShow_trueAfterOneAutoShow() {
        ShareCardTipStorage.markAutoShown()
        XCTAssertTrue(ShareCardTipStorage.shouldShow())
    }

    func test_shouldShow_falseAfterTwoAutoShows() {
        ShareCardTipStorage.markAutoShown()
        ShareCardTipStorage.markAutoShown()
        XCTAssertFalse(ShareCardTipStorage.shouldShow())
    }

    func test_shouldShow_falseWhenDismissedPermanently_evenWithZeroCount() {
        ShareCardTipStorage.markDismissedPermanently()
        XCTAssertFalse(ShareCardTipStorage.shouldShow())
    }

    func test_reset_restoresInitialState() {
        ShareCardTipStorage.markAutoShown()
        ShareCardTipStorage.markAutoShown()
        ShareCardTipStorage.markDismissedPermanently()
        ShareCardTipStorage.reset()
        XCTAssertTrue(ShareCardTipStorage.shouldShow())
    }
}
