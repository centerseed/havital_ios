import XCTest
@testable import paceriz_dev

final class ShareCardCanvasDataBuilderTests: XCTestCase {
    func testHasPaceSeries_falseWhenFewerThanTwoValidSamples() {
        let workout = makeWorkout(paces: [320.0, nil])
        let data = ShareCardCanvasDataBuilder.build(from: workout)
        XCTAssertFalse(data.hasPaceSeries)
        XCTAssertEqual(data.paceSamples.count, 1)
    }

    func testHasPaceSeries_trueWhenTwoOrMoreValidSamples() {
        let workout = makeWorkout(paces: [330.0, 310.0, nil, 300.0])
        let data = ShareCardCanvasDataBuilder.build(from: workout)
        XCTAssertTrue(data.hasPaceSeries)
        XCTAssertEqual(data.paceSamples.count, 3)
    }

    func testHasRoute_falseWhenFewerThanTwoPoints() {
        let workout = makeWorkout(route: [(25.0, 121.5)])
        let data = ShareCardCanvasDataBuilder.build(from: workout)
        XCTAssertFalse(data.hasRoute)
    }

    func testClampNormalized_clampsTo005And095() {
        XCTAssertEqual(ShareCardLayoutMath.clampNormalized(1.2), 0.95, accuracy: 0.0001)
        XCTAssertEqual(ShareCardLayoutMath.clampNormalized(-0.1), 0.05, accuracy: 0.0001)
    }
}

// MARK: - Test Helpers

private func makeWorkout(
    paces: [Double?] = [],
    route: [(Double, Double)] = []
) -> WorkoutV2 {
    let decoder = JSONDecoder()

    var timeSeriesJSON = "null"
    if !paces.isEmpty {
        let timestamps = (0..<paces.count).map { $0 * 60 }
        timeSeriesJSON = """
        {
            "timestamps_s": \(jsonArray(timestamps)),
            "paces_s_per_km": \(jsonOptionalDoubles(paces))
        }
        """
    }

    var routeDataJSON = "null"
    if !route.isEmpty {
        let lats = route.map(\.0)
        let lngs = route.map(\.1)
        routeDataJSON = """
        {
            "latitudes": \(jsonDoubles(lats)),
            "longitudes": \(jsonDoubles(lngs))
        }
        """
    }

    let json = """
    {
        "id": "test-workout",
        "provider": "test",
        "activity_type": "running",
        "duration_seconds": 3600,
        "time_series": \(timeSeriesJSON),
        "route_data": \(routeDataJSON)
    }
    """
    return try! decoder.decode(WorkoutV2.self, from: Data(json.utf8))
}

private func jsonArray(_ values: [Int]) -> String {
    "[\(values.map(String.init).joined(separator: ", "))]"
}

private func jsonDoubles(_ values: [Double]) -> String {
    "[\(values.map { String($0) }.joined(separator: ", "))]"
}

private func jsonOptionalDoubles(_ values: [Double?]) -> String {
    let parts = values.map { value -> String in
        guard let value else { return "null" }
        return String(value)
    }
    return "[\(parts.joined(separator: ", "))]"
}
