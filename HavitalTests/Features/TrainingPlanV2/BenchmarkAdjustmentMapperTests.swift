import XCTest
@testable import paceriz_dev

final class BenchmarkAdjustmentMapperTests: XCTestCase {
    private func entity(from json: String) throws -> AdjustmentItemV2 {
        let dto = try JSONDecoder().decode(AdjustmentItemV2DTO.self, from: Data(json.utf8))
        return WeeklySummaryV2Mapper.testMapAdjustmentItem(dto)
    }
    func test_executeBenchmark_maps_to_execute_payload() throws {
        let e = try entity(from: #"""
        {"content":"c","category":"general","apply":true,"reason":"r","impact":"i","priority":"high",
         "type":"execute_benchmark","value":{"distance_km":5.0,"week":2,"scheduled_weekday":6}}
        """#)
        XCTAssertNotNil(e.benchmarkExecute)
        XCTAssertEqual(e.benchmarkExecute?.distanceKm, 5.0)
        XCTAssertEqual(e.benchmarkExecute?.scheduledWeekday, 6)
        XCTAssertNil(e.benchmarkCalibration)
    }
    func test_adjustVdot_maps_to_calibration_payload() throws {
        let e = try entity(from: #"""
        {"content":"c","category":"general","apply":false,"reason":"r","impact":"i","priority":"high",
         "type":"adjust_vdot","value":{"benchmark_distance_m":5000.0,"benchmark_duration_s":1320.0,
           "should_hedge":false,"workout_date":"2026-06-18",
           "calibration_preview":{"pace_before_s_per_km":330,"pace_after_s_per_km":322,
             "race_distance_label":"半馬","race_time_before_s":6750,"race_time_after_s":6490,
             "vdot_before":42.5,"vdot_after":44.0}}}
        """#)
        XCTAssertNotNil(e.benchmarkCalibration)
        XCTAssertEqual(e.benchmarkCalibration?.distanceKm, 5.0)
        XCTAssertEqual(e.benchmarkCalibration?.durationS, 1320.0)
        XCTAssertEqual(e.benchmarkCalibration?.paceAfterSPerKm, 322)
        XCTAssertFalse(e.benchmarkCalibration?.shouldHedge ?? true)
        XCTAssertNil(e.benchmarkExecute)
    }
    func test_unknownType_maps_to_plain_item_both_nil() throws {
        let e = try entity(from: #"""
        {"content":"c","category":"volume","apply":true,"reason":"r","impact":"i","priority":"medium"}
        """#)
        XCTAssertNil(e.benchmarkExecute)
        XCTAssertNil(e.benchmarkCalibration)
    }
    func test_adjustVdot_missing_calibration_still_maps_payload_with_nil_preview() throws {
        let e = try entity(from: #"""
        {"content":"c","category":"general","apply":false,"reason":"r","impact":"i","priority":"high",
         "type":"adjust_vdot","value":{"benchmark_distance_m":3000.0,"benchmark_duration_s":780.0,
           "should_hedge":true,"workout_date":"2026-06-18"}}
        """#)
        XCTAssertNotNil(e.benchmarkCalibration)
        XCTAssertEqual(e.benchmarkCalibration?.distanceKm, 3.0)
        XCTAssertTrue(e.benchmarkCalibration?.shouldHedge ?? false)
        XCTAssertNil(e.benchmarkCalibration?.paceAfterSPerKm)
    }
}
