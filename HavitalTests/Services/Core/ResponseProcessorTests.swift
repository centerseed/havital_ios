import XCTest
@testable import paceriz_dev

final class ResponseProcessorTests: XCTestCase {
    private struct PlainPayload: Codable, Equatable {
        let value: Int
    }

    func testExtractData_directJSONObject_doesNotMisclassifyAsWrappedResponse() throws {
        let rawData = Data(#"{"value": 42}"#.utf8)

        let result = try ResponseProcessor.extractData(
            PlainPayload.self,
            from: rawData,
            using: DefaultAPIParser.shared
        )

        XCTAssertEqual(result, PlainPayload(value: 42))
    }

    func testExtractData_wrappedResponse_stillUsesWrappedPayload() throws {
        let rawData = Data(#"{"success": true, "data": {"value": 42}}"#.utf8)

        let result = try ResponseProcessor.extractData(
            PlainPayload.self,
            from: rawData,
            using: DefaultAPIParser.shared
        )

        XCTAssertEqual(result, PlainPayload(value: 42))
    }

    /// Prod 2026-08-27 founder payload: `{success, data: <stats fields>}`.
    /// `WorkoutStatsResponse` is itself `{data: WorkoutStatsData}`, so extracting
    /// that type looks for `data.data` and used to Firebase-log missingKey `data`.
    func testExtractData_productionStatsEnvelope_asStatsData() throws {
        let result = try ResponseProcessor.extractData(
            WorkoutStatsData.self,
            from: Self.productionStatsEnvelope,
            using: DefaultAPIParser.shared
        )

        XCTAssertEqual(result.totalWorkouts, 36)
        XCTAssertEqual(result.totalDistanceKm, 177.43, accuracy: 0.001)
        XCTAssertEqual(result.weeklySeries?.count, 1)
        XCTAssertEqual(result.yearToDate?.workoutCount, 187)
    }

    func testExtractData_productionStatsEnvelope_asDoubleWrappedResponse_stillSucceeds() throws {
        let result = try ResponseProcessor.extractData(
            WorkoutStatsResponse.self,
            from: Self.productionStatsEnvelope,
            using: DefaultAPIParser.shared
        )

        XCTAssertEqual(result.data.totalWorkouts, 36)
        XCTAssertEqual(result.data.weeklySeries?.count, 1)
    }

    private static let productionStatsEnvelope = Data("""
    {"success":true,"data":{"period_days":30,"timezone":"Asia/Tokyo","as_of":"2026-08-27",
     "total_workouts":36,"total_distance_km":177.43,"avg_pace_per_km":"06:39",
     "provider_distribution":{"garmin":36},"activity_type_distribution":{"running":31,"other":5},
     "weekly_series":[{"week_start":"2026-07-06","week_end":"2026-07-12","distance_km":40.07,"is_current_week":false}],
     "year_to_date":{"year":2026,"start_date":"2026-01-01","through_date":"2026-08-27","distance_km":1223.87,"workout_count":187}}}
    """.utf8)
}
