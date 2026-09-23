import XCTest
@testable import paceriz_dev

/// Production response fixture for 謝佳晉: `state.race_projection` decoding and projection.
final class App2FinishPredictionTests: XCTestCase {

    private final class RequestSpyHTTPClient: HTTPClient {
        let responseData: Data
        private(set) var requestedPath: String?

        init(responseData: Data) {
            self.responseData = responseData
        }

        func request(
            path: String,
            method: HTTPMethod,
            body: Data?,
            customHeaders: [String: String]?,
            timeout: TimeInterval?
        ) async throws -> Data {
            requestedPath = path
            return responseData
        }

        func stream(
            path: String,
            method: HTTPMethod,
            body: Data?,
            customHeaders: [String: String]?
        ) async throws -> HTTPByteStreamResponse {
            throw URLError(.unsupportedURL)
        }
    }

    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: Self.self)
        let name = "athlete_state_metrics_race_projection_response"
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url, "missing race projection fixture"))
    }

    private func response(from rootData: Data) throws -> AthleteStateMetricsResponse {
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: rootData) as? [String: Any])
        let dataObject = try XCTUnwrap(root["data"] as? [String: Any])
        let payload = try JSONSerialization.data(withJSONObject: dataObject)
        return try JSONDecoder().decode(AthleteStateMetricsResponse.self, from: payload)
    }

    func test_decodesProductionFixtureAndProjectsAllFourRaceTimes() throws {
        let response = try response(from: fixtureData())
        let item = try XCTUnwrap(response.metrics.raceProjection)
        let channels = try XCTUnwrap(item.envelope?.channels)

        XCTAssertEqual(item.itemId, "state.race_projection")
        XCTAssertEqual(item.asOf, "2026-09-23")
        XCTAssertEqual(item.deliveryStatus, "active")
        XCTAssertEqual(channels.fullMarathon?.raw?.projectedSeconds, 9_608)
        XCTAssertEqual(channels.fullMarathon?.raw?.intervalSeconds, [9_047, 10_549])
        XCTAssertEqual(channels.halfMarathon?.raw?.projectedSeconds, 4_702)
        XCTAssertEqual(channels.tenK?.raw?.projectedSeconds, 2_001)
        XCTAssertEqual(channels.fiveK?.raw?.projectedSeconds, 964)
        XCTAssertNil(channels.fiveK?.raw?.intervalSeconds)

        let rows = App2MetricDetailProjection.finishPredictions(from: item)
        XCTAssertEqual(rows.map(\.id), ["5k", "10k", "half_marathon", "full_marathon"])
        XCTAssertEqual(rows.map(\.time), ["0:16:04", "0:33:21", "1:18:22", "2:40:08"])
    }

    func test_metricsDataSourceReadsTheAthleteStateMetricsEndpoint() async throws {
        let client = RequestSpyHTTPClient(responseData: try fixtureData())
        let dataSource = AthleteStateMetricsRemoteDataSource(httpClient: client)

        _ = try await dataSource.fetchMetrics()

        XCTAssertEqual(client.requestedPath, "/v2/athlete-state/metrics")
    }

    func test_seriesDataSourcePinsBothRangeBoundsToTheRaceDay() async throws {
        let response = Data(
            #"{"success":true,"data":{"start_day":"2026-09-22","end_day":"2026-09-22","series":{}}}"#.utf8
        )
        let client = RequestSpyHTTPClient(responseData: response)
        let dataSource = AthleteStateSeriesRemoteDataSource(httpClient: client)

        _ = try await dataSource.fetchMetricSeries(startDay: "2026-09-22", endDay: "2026-09-22")

        XCTAssertEqual(
            client.requestedPath,
            "/v2/athlete-state/metrics/series?start_day=2026-09-22&end_day=2026-09-22"
        )
    }

    func test_seriesDTODecodesTheRaceDayRowAndUsesItsOwnChannelStatus() throws {
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])
        let dataObject = try XCTUnwrap(root["data"] as? [String: Any])
        let metrics = try XCTUnwrap(dataObject["metrics"] as? [String: Any])
        let item = try XCTUnwrap(metrics["race_projection"] as? [String: Any])
        let day = try XCTUnwrap(item["as_of"] as? String)
        let row: [String: Any] = [
            "day": day,
            "item_id": try XCTUnwrap(item["item_id"]),
            "as_of": day,
            "estimator_version": try XCTUnwrap(item["estimator_version"]),
            "delivery_status": try XCTUnwrap(item["delivery_status"]),
            "envelope": try XCTUnwrap(item["envelope"])
        ]
        let payload: [String: Any] = [
            "start_day": day,
            "end_day": day,
            "series": ["race_projection": [row]]
        ]

        let decoded = try JSONDecoder().decode(
            AthleteStateSeriesResponse.self,
            from: JSONSerialization.data(withJSONObject: payload)
        )
        let raceDayRow = try XCTUnwrap(decoded.series["race_projection"]?.first)

        XCTAssertEqual(raceDayRow.day, day)
        XCTAssertEqual(raceDayRow.deliveryStatus, "active")
        XCTAssertEqual(
            App2MetricDetailProjection.estimatedFinish(
                deliveryStatus: raceDayRow.deliveryStatus,
                envelope: raceDayRow.envelope,
                targetDistanceKm: 42
            ),
            "2:40:08"
        )
    }

    func test_targetDistanceMapsToBackendRaceChannels() {
        XCTAssertEqual(App2MetricDetailProjection.raceProjectionChannelKey(distanceKm: 5), "5k")
        XCTAssertEqual(App2MetricDetailProjection.raceProjectionChannelKey(distanceKm: 10), "10k")
        XCTAssertEqual(App2MetricDetailProjection.raceProjectionChannelKey(distanceKm: 21), "half_marathon")
        XCTAssertEqual(App2MetricDetailProjection.raceProjectionChannelKey(distanceKm: 42), "full_marathon")
        XCTAssertEqual(App2MetricDetailProjection.raceProjectionChannelKey(distanceKm: 5.14), "5k")
        XCTAssertNil(App2MetricDetailProjection.raceProjectionChannelKey(distanceKm: 12))
        XCTAssertNil(App2MetricDetailProjection.raceProjectionChannelKey(distanceKm: 30))
    }

    func test_unavailableChannelIsNotDrawn() throws {
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])
        var dataObject = try XCTUnwrap(root["data"] as? [String: Any])
        var metrics = try XCTUnwrap(dataObject["metrics"] as? [String: Any])
        var item = try XCTUnwrap(metrics["race_projection"] as? [String: Any])
        var envelope = try XCTUnwrap(item["envelope"] as? [String: Any])
        var channels = try XCTUnwrap(envelope["channels"] as? [String: Any])
        var fiveK = try XCTUnwrap(channels["5k"] as? [String: Any])
        var raw = try XCTUnwrap(fiveK["raw"] as? [String: Any])
        raw["status"] = "unavailable"
        fiveK["raw"] = raw
        channels["5k"] = fiveK
        envelope["channels"] = channels
        item["envelope"] = envelope
        metrics["race_projection"] = item
        dataObject["metrics"] = metrics
        root["data"] = dataObject

        let changedFixture = try JSONSerialization.data(withJSONObject: root)
        let response = try response(from: changedFixture)
        let rows = App2MetricDetailProjection.finishPredictions(
            from: try XCTUnwrap(response.metrics.raceProjection)
        )

        XCTAssertEqual(rows.map(\.id), ["10k", "half_marathon", "full_marathon"])
        XCTAssertFalse(rows.contains { $0.id == "5k" })
    }

    func test_nonActiveRaceProjectionRowDrawsNoChannels() throws {
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])
        var dataObject = try XCTUnwrap(root["data"] as? [String: Any])
        var metrics = try XCTUnwrap(dataObject["metrics"] as? [String: Any])
        var item = try XCTUnwrap(metrics["race_projection"] as? [String: Any])
        item["delivery_status"] = "indeterminate"
        metrics["race_projection"] = item
        dataObject["metrics"] = metrics
        root["data"] = dataObject

        let response = try response(from: JSONSerialization.data(withJSONObject: root))
        let rows = App2MetricDetailProjection.finishPredictions(
            from: try XCTUnwrap(response.metrics.raceProjection)
        )

        XCTAssertTrue(rows.isEmpty, "row 非 active 時整區不畫")
    }
}
