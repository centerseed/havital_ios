import XCTest
@testable import paceriz_dev

@MainActor
final class DailyStateCardViewModelTests: XCTestCase {
    private final class FakeRepo: DailyStateRepository {
        var card: DailyStateCard?
        var error: Error?
        var applyError: Error?
        func fetchTodayState() async throws -> DailyStateCard {
            if let error { throw error }; return card!
        }
        func applyBenchmark(_ calibration: SameDayBenchmarkCalibration) async throws -> Int? {
            if let applyError { throw applyError }; return 17260
        }
        func scheduleNextBenchmark(_ calibration: SameDayBenchmarkCalibration, weeksAhead: Int) async throws -> Int? { calibration.weekOfTraining + weeksAhead }
    }
    private final class RefreshSpy {
        private(set) var callCount = 0
        func record() { callCount += 1 }
    }
    private func card(locked: Bool, calibration: SameDayBenchmarkCalibration? = nil) -> DailyStateCard {
        DailyStateCard(lens: .pre, source: "llm", headline: "H", factType: nil,
            narrativeText: locked ? nil : "n", chips: ["c"], causeChips: [],
            mileageProgression: nil,
            actionLine: "12K easy", rizoScenario: nil, divergenceFlagText: nil,
            isPaid: !locked, isLocked: locked, upsellReason: locked ? "unlock_full_read" : nil,
            benchmarkCalibration: calibration)
    }
    private func calibration() -> SameDayBenchmarkCalibration {
        SameDayBenchmarkCalibration(
            workoutId: "w1", workoutDate: "2026-07-06",
            benchmarkDistanceM: 3582, benchmarkDurationS: 1092,
            overviewId: "ov1", weekOfTraining: 4, canScheduleNext: true,
            payload: BenchmarkCalibrationPayload(
                workoutDate: "2026-07-06", distanceKm: 3.58, durationS: 1092, shouldHedge: false,
                paceBeforeSPerKm: nil, paceAfterSPerKm: nil, raceDistanceLabel: nil,
                raceTimeBeforeS: 17742, raceTimeAfterS: 17260, vdotBefore: 36.4, vdotAfter: 38.6))
    }

    func test_load_success_sets_loaded() async {
        let repo = FakeRepo(); repo.card = card(locked: false)
        let vm = DailyStateCardViewModel(repository: repo)
        await vm.loadForTest()
        XCTAssertEqual(vm.state.data?.headline, "H")
    }

    func test_load_error_sets_error() async {
        let repo = FakeRepo(); repo.error = URLError(.badServerResponse)
        let vm = DailyStateCardViewModel(repository: repo)
        await vm.loadForTest()
        XCTAssertTrue(vm.state.hasError)
    }

    func test_cancelled_does_not_set_error() async {
        let repo = FakeRepo(); repo.error = URLError(.cancelled)
        let vm = DailyStateCardViewModel(repository: repo)
        await vm.loadForTest()
        XCTAssertFalse(vm.state.hasError)   // cancelled 過濾
    }

    // MARK: - T-0142 套用後即時 sync 完賽預估（readiness force refresh）

    /// 共用 setup:載入帶校準卡的今日狀態,回 (vm, spy, repo)。
    private func makeBenchmarkVM(applyError: Error? = nil) async -> (DailyStateCardViewModel, RefreshSpy, FakeRepo) {
        let repo = FakeRepo(); repo.card = card(locked: false, calibration: calibration())
        repo.applyError = applyError
        let spy = RefreshSpy()
        let vm = DailyStateCardViewModel(repository: repo, refreshReadiness: { spy.record() })
        await vm.loadForTest()
        return (vm, spy, repo)
    }

    func test_applyBenchmark_success_refreshes_readiness_and_dismisses() async {
        let (vm, spy, _) = await makeBenchmarkVM()
        await vm.applyBenchmarkForTest()
        XCTAssertEqual(vm.appliedFinishSeconds, 17260)
        XCTAssertTrue(vm.benchmarkDismissed)
        XCTAssertEqual(spy.callCount, 1)   // 比賽卡片/表現數據靠這個 refresh 才會更新
        XCTAssertFalse(vm.benchmarkApplyFailed)
    }

    func test_applyBenchmark_failure_sets_error_keeps_card_no_refresh() async {
        let (vm, spy, _) = await makeBenchmarkVM(applyError: URLError(.badServerResponse))
        await vm.applyBenchmarkForTest()
        XCTAssertTrue(vm.benchmarkApplyFailed)          // 用戶要看得到失敗
        XCTAssertFalse(vm.benchmarkDismissed)           // 卡片留著可重試
        XCTAssertEqual(spy.callCount, 0)
        XCTAssertFalse(vm.isApplyingBenchmark)
    }

    func test_applyBenchmark_cancelled_no_error_no_refresh() async {
        let (vm, spy, _) = await makeBenchmarkVM(applyError: URLError(.cancelled))
        await vm.applyBenchmarkForTest()
        XCTAssertFalse(vm.benchmarkApplyFailed)         // cancelled 過濾，不是失敗
        XCTAssertEqual(spy.callCount, 0)
    }

    func test_applyBenchmark_retry_after_failure_clears_error() async {
        let (vm, spy, repo) = await makeBenchmarkVM(applyError: URLError(.badServerResponse))
        await vm.applyBenchmarkForTest()
        XCTAssertTrue(vm.benchmarkApplyFailed)
        repo.applyError = nil
        await vm.applyBenchmarkForTest()
        XCTAssertFalse(vm.benchmarkApplyFailed)
        XCTAssertTrue(vm.benchmarkDismissed)
        XCTAssertEqual(spy.callCount, 1)
    }
}
