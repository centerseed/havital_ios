import XCTest
@testable import paceriz_dev

final class HeartRateZonesBridgeTests: XCTestCase {
    private var originalMaxHR: Int?
    private var originalRestingHR: Int?
    private var originalZonesData: Data?

    override func setUp() {
        super.setUp()
        let preferences = UserPreferencesManager.shared
        originalMaxHR = preferences.maxHeartRate
        originalRestingHR = preferences.restingHeartRate
        originalZonesData = preferences.heartRateZones
    }

    override func tearDown() {
        let preferences = UserPreferencesManager.shared
        preferences.maxHeartRate = originalMaxHR
        preferences.restingHeartRate = originalRestingHR
        preferences.heartRateZones = originalZonesData
        super.tearDown()
    }

    func testConvertToHealthKitManagerZones_MapsAllFields() {
        let bridge = HeartRateZonesBridge.shared
        let source = [
            HeartRateZonesManager.HeartRateZone(
                zone: 1,
                name: "Z1",
                range: 100...120,
                description: "easy",
                benefit: "recovery"
            ),
            HeartRateZonesManager.HeartRateZone(
                zone: 2,
                name: "Z2",
                range: 121...140,
                description: "steady",
                benefit: "aerobic"
            ),
        ]

        let mapped = bridge.convertToHealthKitManagerZones(source)

        XCTAssertEqual(mapped.count, 2)
        XCTAssertEqual(mapped[0].id, 1)
        XCTAssertEqual(mapped[0].zone, 1)
        XCTAssertEqual(mapped[0].range.lowerBound, 100)
        XCTAssertEqual(mapped[0].range.upperBound, 120)
        XCTAssertEqual(mapped[0].description, "easy")
        XCTAssertEqual(mapped[0].benefit, "recovery")
    }

    func testEnsureHeartRateZonesAvailable_WhenCached_DoesNotTriggerSync() async {
        let bridge = HeartRateZonesBridge.shared
        let existing = Data("cached-zones".utf8)
        UserPreferencesManager.shared.heartRateZones = existing

        await bridge.ensureHeartRateZonesAvailable()

        XCTAssertEqual(UserPreferencesManager.shared.heartRateZones, existing)
    }

    func testSyncHeartRateZones_WithValidPreferences_CalculatesAndStoresZones() async throws {
        let bridge = HeartRateZonesBridge.shared
        let preferences = UserPreferencesManager.shared
        preferences.maxHeartRate = 190
        preferences.restingHeartRate = 60
        preferences.heartRateZones = nil

        await bridge.syncHeartRateZones()
        try await Task.sleep(nanoseconds: 200_000_000)

        guard let zonesData = preferences.heartRateZones else {
            XCTFail("Expected heart rate zones to be saved")
            return
        }

        let json = try JSONSerialization.jsonObject(with: zonesData) as? [[String: Any]]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?.isEmpty, false)
    }
}
