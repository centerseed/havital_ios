import XCTest
@testable import paceriz_dev

final class TrainingLoadDataManagerTests: XCTestCase {
    private let cacheKey = "training_load_health_data"
    private let lastSyncDateKey = "training_load_last_sync_date"
    private let cacheVersionKey = "training_load_cache_version"

    override func setUp() {
        super.setUp()
        clearTrainingLoadDefaults()
    }

    override func tearDown() {
        clearTrainingLoadDefaults()
        super.tearDown()
    }

    func testGetTrainingLoadData_WhenCacheExists_ReturnsCachedRecords() async throws {
        let records = [
            try makeHealthRecord(date: "2026-04-10", calories: 620),
            try makeHealthRecord(date: "2026-04-09", calories: 580),
        ]
        let encoded = try JSONEncoder().encode(records)

        UserDefaults.standard.set(encoded, forKey: cacheKey)
        UserDefaults.standard.set(Date(), forKey: lastSyncDateKey)
        UserDefaults.standard.set(2, forKey: cacheVersionKey)

        let result = await TrainingLoadDataManager.shared.getTrainingLoadData()

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].date, "2026-04-10")
        XCTAssertEqual(result[1].date, "2026-04-09")
    }

    func testClearCache_RemovesCachedDataAndLastSyncDate() async {
        UserDefaults.standard.set(Data("cached".utf8), forKey: cacheKey)
        UserDefaults.standard.set(Date(), forKey: lastSyncDateKey)

        await TrainingLoadDataManager.shared.clearCache()

        XCTAssertNil(UserDefaults.standard.data(forKey: cacheKey))
        XCTAssertNil(UserDefaults.standard.object(forKey: lastSyncDateKey))
    }

    private func clearTrainingLoadDefaults() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: lastSyncDateKey)
        UserDefaults.standard.removeObject(forKey: cacheVersionKey)
    }

    private func makeHealthRecord(date: String, calories: Int) throws -> HealthRecord {
        let json = """
        {
          "date": "\(date)",
          "daily_calories": \(calories),
          "hrv_last_night_avg": 45.2,
          "resting_heart_rate": 58,
          "tsb_metrics": {
            "atl": 10.0,
            "ctl": 12.0,
            "fitness": 11.0,
            "tsb": -1.0,
            "updated_at": 1710000000,
            "workout_trigger": false,
            "total_tss": 34.5,
            "created_at": "2026-04-10T00:00:00Z"
          }
        }
        """
        let data = Data(json.utf8)
        return try JSONDecoder().decode(HealthRecord.self, from: data)
    }
}
