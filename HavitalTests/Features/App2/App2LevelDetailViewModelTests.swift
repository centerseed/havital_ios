import XCTest
@testable import paceriz_dev

/// 有氧續航／速度耐力詳情頁的 30 天線（T-0617，SPEC-today-state §4.5）。
///
/// 鎖住三件事：
/// 1. 窗是 `asof − 29 … asof`，右端是**卡片的業務日**，不是裝置日期；
/// 2. 序列讀不到不擋頁 —— 那一塊畫佔位句，其餘（hero／分級尺／依據句）照常；
/// 3. 被取消的輪不發布、也不算載過（同其他 detail VM 的護欄）。
@MainActor
final class App2LevelDetailViewModelTests: XCTestCase {

    private final class StubSeriesSource: AthleteStateSeriesDataSourceProtocol {
        var response: AthleteStateSeriesResponse
        var error: Error?
        private(set) var requested: (start: String, end: String)?

        init(response: AthleteStateSeriesResponse, error: Error? = nil) {
            self.response = response
            self.error = error
        }

        func fetchMetricSeries(startDay: String, endDay: String) async throws -> AthleteStateSeriesResponse {
            requested = (startDay, endDay)
            if let error { throw error }
            return response
        }
    }

    private final class HangingSeriesSource: AthleteStateSeriesDataSourceProtocol {
        func fetchMetricSeries(startDay: String, endDay: String) async throws -> AthleteStateSeriesResponse {
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            throw CancellationError()
        }
    }

    private final class TimeoutAfterCancelSeriesSource: AthleteStateSeriesDataSourceProtocol {
        var started = false

        func fetchMetricSeries(startDay: String, endDay: String) async throws -> AthleteStateSeriesResponse {
            started = true
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 5_000_000) } catch { break }
            }
            throw URLError(.timedOut)
        }
    }

    private func response(_ days: [(String, Double?)]) -> AthleteStateSeriesResponse {
        AthleteStateSeriesResponse(
            startDay: nil, endDay: nil,
            series: ["aerobic_endurance": days.map { day, value in
                .init(day: day,
                      deliveryStatus: value == nil ? "not_computed" : "active",
                      envelope: value.map { .init(index: $0, levelIndex: nil) })
            }]
        )
    }

    // MARK: - 窗

    func test_windowIsTwentyNineDaysBeforeTheCardsBusinessDay() {
        let window = App2LevelDetailViewModel.window(asof: "2026-09-06")
        XCTAssertEqual(window.end, "2026-09-06")
        XCTAssertEqual(window.start, "2026-08-08")   // 含頭尾共 30 天
    }

    func test_windowFallsBackToTheDeviceDayWhenTheCardHasNoAsof() {
        let window = App2LevelDetailViewModel.window(asof: nil)
        XCTAssertEqual(window.end, App2MetricDetailProjection.today())
        XCTAssertEqual(
            window.start,
            App2MetricDetailProjection.dateString(byAdding: -29, to: window.end)
        )
    }

    func test_theRequestUsesThatWindow() async {
        let source = StubSeriesSource(response: response([("2026-09-05", 30.0),
                                                          ("2026-09-06", 31.0)]))
        let vm = App2LevelDetailViewModel(itemKey: "aerobic_endurance",
                                          asof: "2026-09-06",
                                          dataSource: source)
        await vm.revalidate()

        XCTAssertEqual(source.requested?.start, "2026-08-08")
        XCTAssertEqual(source.requested?.end, "2026-09-06")
        XCTAssertEqual(vm.detail?.value.series.map(\.value), [30.0, 31.0])
        XCTAssertTrue(vm.hasLoaded)
        XCTAssertFalse(vm.isLoading)
    }

    /// 恢復頁的近 30 天分數線沿用同一支 VM（`recovery_index`），不另寫第二份讀法。
    func test_recoveryIndexReadsThroughTheSameViewModel() async {
        let payload = AthleteStateSeriesResponse(
            startDay: nil, endDay: nil,
            series: ["recovery_index": [
                .init(day: "2026-09-05", deliveryStatus: "active", envelope: .init(index: 72, levelIndex: nil)),
                .init(day: "2026-09-06", deliveryStatus: "active", envelope: .init(index: 65, levelIndex: nil))
            ]]
        )
        let source = StubSeriesSource(response: payload)
        let vm = App2LevelDetailViewModel(itemKey: "recovery_index", asof: "2026-09-06", dataSource: source)
        await vm.revalidate()

        XCTAssertEqual(source.requested?.start, "2026-08-08")
        XCTAssertEqual(source.requested?.end, "2026-09-06")
        XCTAssertEqual(vm.detail?.value.series.map(\.value), [72, 65])
    }

    // MARK: - 讀不到不擋頁

    func test_aFailedReadLeavesNoSeriesButStillCountsAsLoaded() async {
        let source = StubSeriesSource(response: response([]),
                                      error: URLError(.timedOut))
        let vm = App2LevelDetailViewModel(itemKey: "aerobic_endurance",
                                          asof: "2026-09-06",
                                          dataSource: source)
        await vm.revalidate()

        XCTAssertNil(vm.detail, "讀失敗不得發布一份空序列冒充結果")
        XCTAssertFalse(vm.isLoading, "失敗後 spinner 要收掉，畫面走佔位句")
        XCTAssertTrue(vm.hasLoaded, "真失敗算載過（重驗門檻照走），只有取消不算")
    }

    func test_daysWithoutARowAreSkippedNotCarriedForward() async {
        let source = StubSeriesSource(response: response([("2026-09-04", 28.0),
                                                          ("2026-09-05", nil),
                                                          ("2026-09-06", 24.0)]))
        let vm = App2LevelDetailViewModel(itemKey: "aerobic_endurance",
                                          asof: "2026-09-06",
                                          dataSource: source)
        await vm.revalidate()

        XCTAssertEqual(vm.detail?.value.series.map(\.date), ["2026-09-04", "2026-09-06"])
    }

    func test_failedInitialReadDoesNotClaimASuccessfulRefreshTime() async {
        let source = StubSeriesSource(response: response([]), error: URLError(.timedOut))
        let vm = App2LevelDetailViewModel(itemKey: "aerobic_endurance",
                                         asof: "2026-09-06", dataSource: source)
        await vm.revalidate()
        XCTAssertNil(vm.lastLoadedAt, "A transport failure is not a successful refresh")
        XCTAssertTrue(vm.readFailed)
    }

    func test_failedRefreshKeepsThePreviousResultAndItsSuccessfulRefreshTime() async {
        let source = StubSeriesSource(response: response([("2026-09-05", 28)]))
        let vm = App2LevelDetailViewModel(itemKey: "aerobic_endurance",
                                         asof: "2026-09-06", dataSource: source)
        await vm.revalidate()
        let successfulRead = vm.lastLoadedAt
        XCTAssertNotNil(successfulRead)
        source.error = URLError(.timedOut)
        await vm.revalidate()
        XCTAssertEqual(vm.detail?.value.series.map(\.date), ["2026-09-05"])
        XCTAssertEqual(vm.detail?.value.series.map(\.value), [28])
        XCTAssertTrue(vm.readFailed)
        XCTAssertEqual(vm.lastLoadedAt, successfulRead,
                       "Keeping an old value must not mark it as freshly read")
    }

    func test_successfulRetryClearsFailureAndPublishesFreshResult() async {
        let source = StubSeriesSource(response: response([]), error: URLError(.timedOut))
        let vm = App2LevelDetailViewModel(itemKey: "aerobic_endurance",
                                         asof: "2026-09-06", dataSource: source)
        await vm.revalidate()
        XCTAssertTrue(vm.readFailed)
        source.error = nil
        source.response = response([("2026-09-06", 31)])
        await vm.forceRefresh()
        XCTAssertFalse(vm.readFailed)
        XCTAssertNotNil(vm.lastLoadedAt)
        XCTAssertEqual(vm.detail?.value.series.map(\.value), [31])
    }

    // MARK: - 取消

    func test_aCancelledRoundPublishesNothing() async {
        let vm = App2LevelDetailViewModel(itemKey: "speed_endurance",
                                          asof: "2026-09-06",
                                          dataSource: HangingSeriesSource())
        let load = Task { await vm.revalidate() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        load.cancel()
        await load.value

        XCTAssertNil(vm.detail, "被取消的載入輪不得發布 detail")
        XCTAssertFalse(vm.isLoading, "取消後 spinner 要收掉")
        XCTAssertFalse(vm.hasLoaded, "取消不算載過")
        XCTAssertFalse(vm.readFailed)
        XCTAssertNil(vm.lastLoadedAt)
    }

    func test_cancelledRoundWithTransportError_doesNotSetReadFailed() async {
        let source = TimeoutAfterCancelSeriesSource()
        let vm = App2LevelDetailViewModel(itemKey: "aerobic_endurance",
                                          asof: "2026-09-06",
                                          dataSource: source)
        let load = Task { await vm.revalidate() }
        let deadline = Date().addingTimeInterval(5)
        while !source.started, Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        vm.cancelInFlightReload()
        await load.value
        XCTAssertFalse(vm.readFailed)
        XCTAssertFalse(vm.hasLoaded)
        XCTAssertNil(vm.detail)
        XCTAssertNil(vm.lastLoadedAt)
    }
}
