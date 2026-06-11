import XCTest
@testable import paceriz_dev

final class BenchmarkAdjustmentDecodeTests: XCTestCase {
    private func decode(_ json: String) throws -> AdjustmentItemV2DTO {
        try JSONDecoder().decode(AdjustmentItemV2DTO.self, from: Data(json.utf8))
    }
    func test_executeBenchmark_decodes_type_and_value() throws {
        let dto = try decode(#"""
        {"content":"c","category":"general","apply":true,"reason":"r","impact":"i","priority":"high",
         "type":"execute_benchmark",
         "value":{"overview_id":"ov_5","week":2,"distance_km":5.0,"scheduled_weekday":6}}
        """#)
        XCTAssertEqual(dto.type, "execute_benchmark")
        XCTAssertEqual(dto.value?.distanceKm, 5.0)
        XCTAssertEqual(dto.value?.scheduledWeekday, 6)
    }
    func test_adjustVdot_decodes_calibration_preview() throws {
        let dto = try decode(#"""
        {"content":"c","category":"general","apply":false,"reason":"r","impact":"i","priority":"high",
         "type":"adjust_vdot",
         "value":{"benchmark_distance_m":5000.0,"benchmark_duration_s":1320.0,"should_hedge":false,
           "suggested_change_rounded":1.5,"workout_date":"2026-06-18","overview_id":"ov_5",
           "calibration_preview":{"pace_before_s_per_km":330,"pace_after_s_per_km":322,
             "race_distance_label":"半馬","race_distance_km":21.0975,
             "race_time_before_s":6750,"race_time_after_s":6490,
             "vdot_before":42.5,"vdot_after":44.0}}}
        """#)
        XCTAssertEqual(dto.type, "adjust_vdot")
        XCTAssertEqual(dto.value?.calibrationPreview?.paceAfterSPerKm, 322)
        XCTAssertEqual(dto.value?.calibrationPreview?.raceTimeAfterS, 6490)
    }
    func test_unknownType_and_missingValue_decodes_to_nil_no_crash() throws {
        let dto = try decode(#"""
        {"content":"c","category":"volume","apply":true,"reason":"r","impact":"i","priority":"medium"}
        """#)
        XCTAssertNil(dto.type)
        XCTAssertNil(dto.value)
    }
}
