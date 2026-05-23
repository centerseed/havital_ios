import XCTest
@testable import paceriz_dev

final class ClimateAdjustmentSyncStoreTests: XCTestCase {
    private let suiteName = "ClimateAdjustmentSyncStoreTests"
    private let key = "climateAdjustmentEnabled"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func test_saveReadAndRemoveUsesSharedClimateAdjustmentKey() {
        XCTAssertNil(ClimateAdjustmentSyncStore.read(defaults: defaults))

        ClimateAdjustmentSyncStore.setEnabled(true, defaults: defaults)
        XCTAssertEqual(ClimateAdjustmentSyncStore.read(defaults: defaults), true)
        XCTAssertEqual(defaults.object(forKey: key) as? Bool, true)

        ClimateAdjustmentSyncStore.setEnabled(false, defaults: defaults)
        XCTAssertEqual(ClimateAdjustmentSyncStore.read(defaults: defaults), false)
        XCTAssertEqual(defaults.object(forKey: key) as? Bool, false)

        ClimateAdjustmentSyncStore.remove(defaults: defaults)
        XCTAssertNil(ClimateAdjustmentSyncStore.read(defaults: defaults))
        XCTAssertNil(defaults.object(forKey: key))
    }
}
