import XCTest
@testable import paceriz_dev

final class ClimateForecastRemoteDataSourceTests: XCTestCase {
    private var sut: ClimateForecastRemoteDataSource!
    private var mockHTTPClient: MockHTTPClient!
    private var mockAuthSessionRepository: MockAuthSessionRepository!

    override func setUp() {
        super.setUp()
        mockHTTPClient = MockHTTPClient()
        mockAuthSessionRepository = MockAuthSessionRepository()
        mockAuthSessionRepository.currentUser = AuthUser(uid: "runner-1", email: "runner@example.com")
        sut = ClimateForecastRemoteDataSource(
            httpClient: mockHTTPClient,
            parser: DefaultAPIParser.shared,
            authSessionRepository: mockAuthSessionRepository
        )
    }

    override func tearDown() {
        mockHTTPClient.reset()
        sut = nil
        mockHTTPClient = nil
        mockAuthSessionRepository = nil
        super.tearDown()
    }

    func test_fetchForecast_requestsSevenDayClimateForecast() async throws {
        let response = """
        {
          "success": true,
          "data": {
            "uid": "runner-1",
            "locale": "zh-TW",
            "enabled": true,
            "region_key": "taiwan",
            "source": "Open-Meteo apparent temperature",
            "start_date": "2026-05-23",
            "days_requested": 7,
            "data_status": "ready",
            "snapshot_refreshed_at": "2026-05-23T00:00:00+00:00",
            "settings": {
              "enabled": true,
              "adaptation_level": "normal",
              "manual_start_threshold_c": null,
              "region_key": "taiwan"
            },
            "days": [
              {
                "day_index": 1,
                "date": "2026-05-23",
                "feels_like_temp_c": 31.2,
                "heat_pressure_level": "moderate",
                "pace_adjustment_pct": 4.0,
                "long_run_reduction_pct": 0.8,
                "reason_text": "中度熱壓力，建議配速下修 3-5%，長跑保留約 80%。",
                "source": "open_meteo",
                "warning_label": "已達中央氣象署高溫提醒等級。",
                "region_key": "taiwan",
                "snapshot_id": "forecast_daily:taiwan:2026-05-23:7",
                "point_id": "forecast_daily:taiwan:2026-05-23:7:2026-05-23",
                "is_adjusted": true
              }
            ]
          }
        }
        """.data(using: .utf8)!

        mockHTTPClient.setResponse(
            for: "/v1/users/runner-1/climate/forecast?days=7",
            method: .GET,
            data: response
        )

        let forecast = try await sut.fetchForecast(days: 7)

        XCTAssertEqual(forecast.uid, "runner-1")
        XCTAssertEqual(forecast.enabled, true)
        XCTAssertEqual(forecast.regionKey, "taiwan")
        XCTAssertEqual(forecast.days.count, 1)
        XCTAssertEqual(forecast.days[0].date, "2026-05-23")
        XCTAssertEqual(forecast.days[0].feelsLikeTempC, 31.2)
        XCTAssertEqual(forecast.days[0].heatPressureLevel, "moderate")
        XCTAssertEqual(forecast.days[0].paceAdjustmentPct, 4.0)
        XCTAssertTrue(forecast.days[0].isAdjusted)
        XCTAssertTrue(mockHTTPClient.wasPathCalled("/v1/users/runner-1/climate/forecast?days=7", method: .GET))
    }
}
