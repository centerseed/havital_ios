import XCTest
@testable import paceriz_dev

/// 訓練詳情的「強度區間佔比」——2026-09-02（frame-index（z1））補的區塊。
///
/// 這一份鎖兩件事，都是外部審查在 T-0394 指出來的實際風險：
/// 1. **取值來源**：詳情優先、列表模型 fallback。列表那一筆的 `advanced_metrics` 常常
///    是空的，只讀列表會在詳情明明有區間資料時整塊不顯示。
/// 2. **要畫哪幾條**：沒有值的區間不佔一列；某一組缺席時 picker 不得停在空的那一頁。
final class App2WorkoutZoneDistributionTests: XCTestCase {

    // MARK: - Helpers

    private func zoneJSON(
        recovery: Double? = nil,
        easy: Double? = nil,
        marathon: Double? = nil,
        threshold: Double? = nil,
        anaerobic: Double? = nil,
        interval: Double? = nil
    ) -> [String: Any] {
        var dict: [String: Any] = [:]
        if let recovery { dict["recovery"] = recovery }
        if let easy { dict["easy"] = easy }
        if let marathon { dict["marathon"] = marathon }
        if let threshold { dict["threshold"] = threshold }
        if let anaerobic { dict["anaerobic"] = anaerobic }
        if let interval { dict["interval"] = interval }
        return dict
    }

    private func detail(hr: [String: Any]? = nil, pace: [String: Any]? = nil) -> WorkoutV2Detail {
        var advanced: [String: Any] = [:]
        if let hr { advanced["hr_zone_distribution"] = hr }
        if let pace { advanced["pace_zone_distribution"] = pace }
        let json: [String: Any] = [
            "id": "w1",
            "provider": "garmin",
            "activity_type": "running",
            "start_time": "2026-09-01T06:32:00Z",
            "end_time": "2026-09-01T07:30:00Z",
            "user_id": "u1",
            "schema_version": "2.0",
            "source": "garmin",
            "storage_path": "/workouts/w1",
            "original_id": "orig_w1",
            "provider_user_id": "garmin_u1",
            "advanced_metrics": advanced,
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(WorkoutV2Detail.self, from: data)
    }

    private func workout(hr: [String: Any]? = nil, pace: [String: Any]? = nil) -> WorkoutV2 {
        var advanced: [String: Any] = [:]
        if let hr { advanced["hr_zone_distribution"] = hr }
        if let pace { advanced["pace_zone_distribution"] = pace }
        let json: [String: Any] = [
            "id": "w1",
            "provider": "garmin",
            "activity_type": "running",
            "start_time_utc": "2026-09-01T06:32:00Z",
            "duration_seconds": 3504,
            "distance_meters": 12_050,
            "advanced_metrics": advanced,
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(WorkoutV2.self, from: data)
    }

    private func zones(_ dict: [String: Any]) -> V2ZoneDistribution {
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return try! JSONDecoder().decode(V2ZoneDistribution.self, from: data)
    }

    // MARK: - 取值來源：詳情優先、列表 fallback

    func test_zones_useDetailWhenListHasNone() {
        let result = App2WorkoutDetailProjection.zoneDistributions(
            detail: detail(hr: zoneJSON(recovery: 12.5), pace: zoneJSON(easy: 40.0)),
            workout: workout()
        )
        XCTAssertEqual(result.heartRate?.recovery, 12.5)
        XCTAssertEqual(result.pace?.easy, 40.0)
    }

    func test_zones_fallBackToListWhenDetailHasNone() {
        let result = App2WorkoutDetailProjection.zoneDistributions(
            detail: detail(),
            workout: workout(hr: zoneJSON(recovery: 8.0), pace: zoneJSON(easy: 33.0))
        )
        XCTAssertEqual(result.heartRate?.recovery, 8.0)
        XCTAssertEqual(result.pace?.easy, 33.0)
    }

    func test_zones_fallBackIsPerGroup() {
        // 詳情只有心率、列表只有配速 —— 兩組各自取到值，不因為其中一組缺席就整批退回列表。
        let result = App2WorkoutDetailProjection.zoneDistributions(
            detail: detail(hr: zoneJSON(recovery: 20.0)),
            workout: workout(pace: zoneJSON(easy: 55.0))
        )
        XCTAssertEqual(result.heartRate?.recovery, 20.0)
        XCTAssertEqual(result.pace?.easy, 55.0)
    }

    func test_zones_detailWinsOverList() {
        let result = App2WorkoutDetailProjection.zoneDistributions(
            detail: detail(hr: zoneJSON(recovery: 1.0)),
            workout: workout(hr: zoneJSON(recovery: 99.0))
        )
        XCTAssertEqual(result.heartRate?.recovery, 1.0)
    }

    func test_zones_bothMissingIsNil() {
        let result = App2WorkoutDetailProjection.zoneDistributions(
            detail: detail(),
            workout: workout()
        )
        XCTAssertNil(result.heartRate)
        XCTAssertNil(result.pace)
    }

    func test_zones_noDetailYetStillReadsList() {
        // 詳情還沒回來（nil）時仍畫列表帶來的那一份，不是等到詳情才出現。
        let result = App2WorkoutDetailProjection.zoneDistributions(
            detail: nil,
            workout: workout(hr: zoneJSON(recovery: 5.0))
        )
        XCTAssertEqual(result.heartRate?.recovery, 5.0)
    }

    // MARK: - 要畫哪幾條

    func test_rows_sixZonesInLowToHighOrder() {
        let hr = zones(zoneJSON(
            recovery: 10, easy: 20, marathon: 30, threshold: 15, anaerobic: 15, interval: 10
        ))
        let rows = ZoneDistributionChartView.rows(for: .heartRate, hrZones: hr, paceZones: nil)
        XCTAssertEqual(
            rows.map(\.key),
            ["recovery", "aerobic", "marathon", "threshold", "anaerobic", "interval"]
        )
        XCTAssertEqual(rows.map(\.percentage), [10, 20, 30, 15, 15, 10])
    }

    func test_rows_omitMissingZones() {
        let hr = zones(zoneJSON(recovery: 40, threshold: 60))
        let rows = ZoneDistributionChartView.rows(for: .heartRate, hrZones: hr, paceZones: nil)
        XCTAssertEqual(rows.map(\.key), ["recovery", "threshold"])
    }

    func test_rows_emptyWhenThatGroupIsMissing() {
        let hr = zones(zoneJSON(recovery: 40))
        XCTAssertTrue(ZoneDistributionChartView.rows(for: .pace, hrZones: hr, paceZones: nil).isEmpty)
    }

    func test_rows_paceGroupReadsPaceZones() {
        let pace = zones(zoneJSON(easy: 70, marathon: 30))
        let rows = ZoneDistributionChartView.rows(for: .pace, hrZones: nil, paceZones: pace)
        XCTAssertEqual(rows.map(\.key), ["aerobic", "marathon"])
        XCTAssertEqual(rows.map(\.percentage), [70, 30])
    }

    // MARK: - 只有一組時不停在空的那一頁

    func test_effectiveTab_bothPresentKeepsSelection() {
        let hr = zones(zoneJSON(recovery: 10))
        let pace = zones(zoneJSON(easy: 10))
        XCTAssertEqual(
            ZoneDistributionChartView.effectiveTab(selected: .pace, hrZones: hr, paceZones: pace),
            .pace
        )
    }

    func test_effectiveTab_paceOnlyIgnoresHeartRateSelection() {
        let pace = zones(zoneJSON(easy: 10))
        XCTAssertEqual(
            ZoneDistributionChartView.effectiveTab(selected: .heartRate, hrZones: nil, paceZones: pace),
            .pace
        )
    }

    func test_effectiveTab_heartRateOnly() {
        let hr = zones(zoneJSON(recovery: 10))
        XCTAssertEqual(
            ZoneDistributionChartView.effectiveTab(selected: .pace, hrZones: hr, paceZones: nil),
            .heartRate
        )
    }
}
