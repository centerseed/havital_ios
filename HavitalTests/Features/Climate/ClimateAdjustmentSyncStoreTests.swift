import XCTest
@testable import paceriz_dev

final class ClimateAdjustmentSyncStoreTests: XCTestCase {
    private let key = "climateAdjustmentEnabled"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    func test_setEnabled_writesSharedClimateAdjustmentKey() {
        ClimateAdjustmentSyncStore.setEnabled(true)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: key))

        ClimateAdjustmentSyncStore.setEnabled(false)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: key))
    }
}
