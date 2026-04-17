import XCTest
@testable import paceriz_dev

@MainActor
final class TrainingReadinessViewModelTests: XCTestCase {
    private var manager: TrainingReadinessManager!
    private var originalIsLoading: Bool = false
    private var originalReadinessData: TrainingReadinessResponse?
    private var originalSyncError: String?
    private var originalLastSyncTime: Date?

    override func setUp() async throws {
        try await super.setUp()
        manager = TrainingReadinessManager.shared

        originalIsLoading = manager.isLoading
        originalReadinessData = manager.readinessData
        originalSyncError = manager.syncError
        originalLastSyncTime = manager.lastSyncTime
    }

    override func tearDown() async throws {
        manager.isLoading = originalIsLoading
        manager.readinessData = originalReadinessData
        manager.syncError = originalSyncError
        manager.lastSyncTime = originalLastSyncTime
        manager = nil
        try await super.tearDown()
    }

    func testInit_SyncsInitialManagerState() {
        manager.isLoading = true
        manager.syncError = "mock-error"
        manager.lastSyncTime = Date(timeIntervalSince1970: 1_700_000_000)
        manager.readinessData = makeReadinessResponse(
            overallScore: 88,
            overallStatusText: "準備度優秀\n可安排品質課",
            withMetrics: true
        )

        let viewModel = TrainingReadinessViewModel(manager: manager)

        XCTAssertTrue(viewModel.isLoading)
        XCTAssertEqual(viewModel.syncError, "mock-error")
        XCTAssertEqual(viewModel.overallScore ?? -1, 88, accuracy: 0.001)
        XCTAssertEqual(viewModel.overallScoreFormatted, "88")
        XCTAssertEqual(viewModel.overallStatusLines, ["準備度優秀", "可安排品質課"])
        XCTAssertTrue(viewModel.hasData)
        XCTAssertTrue(viewModel.hasAnyMetric)
    }

    func testComputedProperties_WhenNoData_ReturnsFallbackValues() {
        manager.isLoading = false
        manager.syncError = nil
        manager.lastSyncTime = nil
        manager.readinessData = nil

        let viewModel = TrainingReadinessViewModel(manager: manager)

        XCTAssertEqual(viewModel.overallScoreFormatted, "--")
        XCTAssertFalse(viewModel.hasData)
        XCTAssertFalse(viewModel.hasAnyMetric)
        XCTAssertTrue(viewModel.shouldShowEmptyState)
        XCTAssertEqual(
            viewModel.dataStatusDescription,
            NSLocalizedString("training_readiness.no_data", comment: "")
        )
        XCTAssertEqual(viewModel.lastUpdatedDescription, "")
    }

    func testDataStatusDescription_PrioritizesLoadingThenErrorThenDataState() {
        manager.readinessData = nil
        let viewModel = TrainingReadinessViewModel(manager: manager)

        viewModel.isLoading = true
        viewModel.syncError = nil
        XCTAssertEqual(
            viewModel.dataStatusDescription,
            NSLocalizedString("common.loading", comment: "")
        )

        viewModel.isLoading = false
        viewModel.syncError = "network error"
        XCTAssertEqual(viewModel.dataStatusDescription, "network error")

        viewModel.syncError = nil
        viewModel.readinessData = makeReadinessResponse(overallScore: 70, withMetrics: true)
        XCTAssertEqual(
            viewModel.dataStatusDescription,
            NSLocalizedString("training_readiness.data_ready", comment: "")
        )
    }

    func testObserverBinding_UpdatesWhenManagerChanges() {
        let viewModel = TrainingReadinessViewModel(manager: manager)
        manager.isLoading = false
        manager.syncError = nil
        manager.readinessData = nil

        manager.isLoading = true
        manager.syncError = "later-error"
        manager.readinessData = makeReadinessResponse(overallScore: 76, withMetrics: true)
        manager.lastSyncTime = Date(timeIntervalSince1970: 1_710_000_000)

        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertTrue(viewModel.isLoading)
        XCTAssertEqual(viewModel.syncError, "later-error")
        XCTAssertEqual(viewModel.overallScoreFormatted, "76")

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        XCTAssertEqual(
            viewModel.lastUpdatedDescription,
            formatter.string(from: Date(timeIntervalSince1970: 1_710_000_000))
        )
    }

    func testMetricHelpers_AndFormattingWorkAsExpected() {
        manager.readinessData = makeReadinessResponse(overallScore: 91, withMetrics: true)
        let viewModel = TrainingReadinessViewModel(manager: manager)

        XCTAssertNotNil(viewModel.speedMetric)
        XCTAssertNotNil(viewModel.enduranceMetric)
        XCTAssertNotNil(viewModel.raceFitnessMetric)
        XCTAssertNotNil(viewModel.trainingLoadMetric)
        XCTAssertNotNil(viewModel.recoveryMetric)

        XCTAssertEqual(viewModel.estimatedRaceTime, "2:59:00")
        XCTAssertEqual(viewModel.formatScore(87.6), "88")
        XCTAssertEqual(viewModel.formatPercentage(82.34), "82.3%")
        XCTAssertEqual(viewModel.formatTSB(-6.78), "-6.8")
        XCTAssertEqual(viewModel.getStatusLines("第一行\n第二行"), ["第一行", "第二行"])
    }

    private func makeReadinessResponse(
        overallScore: Double,
        overallStatusText: String? = nil,
        withMetrics: Bool
    ) -> TrainingReadinessResponse {
        let metrics: TrainingReadinessMetrics? = withMetrics
            ? TrainingReadinessMetrics(
                speed: SpeedMetric(
                    score: 80,
                    achievementRate: 0.8,
                    statusText: "速度穩定",
                    description: "速度良好",
                    trendData: nil,
                    recentWorkouts: nil,
                    trend: "stable",
                    message: nil
                ),
                endurance: EnduranceMetric(
                    score: 78,
                    longRunCompletion: 0.75,
                    volumeConsistency: 0.7,
                    statusText: "耐力中等",
                    description: "可再提升",
                    trendData: nil,
                    trend: "improving",
                    message: nil
                ),
                raceFitness: RaceFitnessMetric(
                    score: 85,
                    racePaceTrainingQuality: 0.9,
                    timeToRaceDays: 30,
                    readinessLevel: "good",
                    statusText: "賽能佳",
                    description: "維持節奏",
                    trendData: nil,
                    estimatedRaceTime: "2:59:00",
                    message: nil
                ),
                trainingLoad: TrainingLoadMetric(
                    score: 74,
                    currentTsb: -5.2,
                    ctl: 56,
                    atl: 61,
                    balanceStatus: "balanced",
                    statusText: "負荷正常",
                    description: "可持續",
                    trendData: nil,
                    message: nil
                ),
                recovery: RecoveryMetric(
                    score: 72,
                    restDaysCount: 1,
                    recoveryQuality: "normal",
                    fatigueLevel: "low",
                    statusText: "恢復尚可",
                    trendData: nil,
                    message: nil
                )
            )
            : nil

        return TrainingReadinessResponse(
            date: "2026-04-14",
            overallScore: overallScore,
            overallStatusText: overallStatusText,
            lastUpdatedTime: "10:30 更新",
            metrics: metrics,
            dataSource: "mock",
            lastUpdated: "2026-04-14T10:30:00Z"
        )
    }
}
