@testable import paceriz_dev

final class App2EmptyAthleteStateMetricsDataSource: AthleteStateMetricsDataSourceProtocol {
    func fetchMetrics() async throws -> AthleteStateMetricsResponse {
        AthleteStateMetricsResponse(metrics: .init(raceProjection: nil))
    }
}

final class App2StaticAthleteStateMetricsDataSource: AthleteStateMetricsDataSourceProtocol {
    let response: AthleteStateMetricsResponse

    init(response: AthleteStateMetricsResponse? = nil) {
        self.response = response ?? Self.computedRaceProjectionResponse()
    }

    func fetchMetrics() async throws -> AthleteStateMetricsResponse {
        response
    }

    private static func computedRaceProjectionResponse() -> AthleteStateMetricsResponse {
        func channel(_ seconds: Int) -> AthleteStateRaceProjectionChannel {
            AthleteStateRaceProjectionChannel(
                raw: .init(projectedSeconds: seconds, intervalSeconds: nil, status: "computed")
            )
        }

        let channels = AthleteStateMetricEnvelope.Channels(
            acwr: nil,
            fiveK: channel(964),
            tenK: channel(2_001),
            halfMarathon: channel(4_702),
            fullMarathon: channel(9_608)
        )
        let item = AthleteStateRaceProjectionItem(
            itemId: "state.race_projection",
            asOf: "2026-09-23",
            estimatorVersion: "race_projection_capability_center_v1",
            deliveryStatus: "active",
            envelope: AthleteStateMetricEnvelope(index: nil, levelIndex: nil, channels: channels)
        )
        return AthleteStateMetricsResponse(metrics: .init(raceProjection: item))
    }
}

final class App2EmptyAthleteStateSeriesDataSource: AthleteStateSeriesDataSourceProtocol {
    func fetchMetricSeries(startDay: String, endDay: String) async throws -> AthleteStateSeriesResponse {
        AthleteStateSeriesResponse(startDay: startDay, endDay: endDay, series: [:])
    }
}
