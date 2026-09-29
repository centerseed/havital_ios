import XCTest
@testable import paceriz_dev

/// §51 訓練量詳情頁的負荷比（T-0618，SPEC-today-state §5.1／§4.5）。
///
/// 鎖住四件事：
/// 1. hero 的大數字與判語**照抄首頁那一列**（同一個量在兩個畫面上必須是同一個字）；
/// 2. 上一完整週公里數退到副標，用後端組好的那一句，不在 app 端重拼；
/// 3. 30 天序列的窗右端是**卡片的業務日**，不是裝置日期；
/// 4. 序列讀不到只少那一塊，週跑量長條圖與統計照常。
@MainActor
final class App2VolumeDetailAcwrTests: XCTestCase {

    // MARK: - Stubs

    private final class StatsSource: WorkoutStatsDataSourceProtocol {
        func fetchWorkoutStats(days: Int, weeks: Int?) async throws -> WorkoutStatsResponse {
            let json = """
            { "data": { "total_workouts": 3, "total_distance_km": 21.0,
                        "provider_distribution": {}, "activity_type_distribution": {},
                        "period_days": 30,
                        "weekly_series": [
                          {"week_start": "2026-08-31", "week_end": "2026-09-06",
                           "distance_km": 12.0, "is_current_week": true},
                          {"week_start": "2026-08-24", "week_end": "2026-08-30",
                           "distance_km": 27.0, "is_current_week": false}
                        ] } }
            """
            return try JSONDecoder().decode(WorkoutStatsResponse.self, from: Data(json.utf8))
        }

        func fetchRecentWorkouts(pageSize: Int) async throws -> [WorkoutV2] { [] }

        func fetchWorkoutsPage(pageSize: Int?, cursor: String?) async throws -> WorkoutListResponse {
            WorkoutListResponse(
                workouts: [],
                pagination: PaginationInfo(
                    nextCursor: nil, prevCursor: nil, hasMore: false, hasNewer: false,
                    oldestId: nil, newestId: nil, totalItems: nil, pageSize: pageSize
                )
            )
        }
    }

    private final class EmptyHealthSource: HealthDailyDataSourceProtocol {
        func fetchHealthDaily(limit: Int) async throws -> HealthDailyResponse {
            try JSONDecoder().decode(
                HealthDailyResponse.self,
                from: Data(#"{ "health_data": [], "count": 0, "limit": 28 }"#.utf8)
            )
        }
    }

    private final class RecordingSeriesSource: AthleteStateSeriesDataSourceProtocol {
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

    private func acwrResponse(_ days: [(String, Double)]) -> AthleteStateSeriesResponse {
        AthleteStateSeriesResponse(
            startDay: nil, endDay: nil,
            series: ["load_index": days.map { day, ratio in
                .init(day: day, deliveryStatus: "active",
                      envelope: .init(
                        index: 90.0, levelIndex: nil,
                        channels: .init(acwr: .init(
                            raw: ratio, available: true, side: "overload",
                            sweetLow: 0.8, sweetHigh: 1.3))))
            }]
        )
    }

    private func volumeInsight(
        value: String? = "1.7",
        verdict: String? = "負荷偏高，近一週比近一個月多 71%，留意",
        change: String? = "上週 27 km"
    ) -> App2Insight {
        App2Insight(
            id: "weekly_volume", label: "訓練量", value: value,
            direction: .up, verdict: verdict, change: change
        )
    }

    private func makeVM(
        insight: App2Insight? = nil,
        narrative: String? = nil,
        series: RecordingSeriesSource,
        planRepository: TrainingPlanV2Repository? = nil
    ) -> App2VolumeDetailViewModel {
        App2VolumeDetailViewModel(
            insight: insight ?? volumeInsight(),
            narrative: narrative,
            asof: "2026-09-06",
            workoutDataSource: StatsSource(),
            healthDataSource: EmptyHealthSource(),
            seriesDataSource: series,
            planRepository: planRepository,
            cache: App2MetricDetailCache()
        )
    }

    private func user(currentWeekDistance: Int) -> User {
        let json = """
        {"current_week_distance": \(currentWeekDistance)}
        """
        return try! JSONDecoder().decode(User.self, from: Data(json.utf8))
    }

    private func planStatus(currentWeekPlanId: String?) -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: 3,
            totalWeeks: 12,
            nextAction: currentWeekPlanId == nil ? "create_plan" : "view_plan",
            canGenerateNextWeek: false,
            currentWeekPlanId: currentWeekPlanId,
            previousWeekSummaryId: nil,
            targetType: "race_run",
            methodologyId: "paceriz",
            nextWeekInfo: nil,
            metadata: nil
        )
    }

    private func weeklyPlan(totalDistance: Double) -> WeeklyPlanV2 {
        WeeklyPlanV2(
            planId: "plan-3", weekOfTraining: 3, id: "plan-3", purpose: "build",
            weekOfPlan: 3, totalWeeks: 12, totalDistance: totalDistance,
            totalDistanceDisplay: nil, totalDistanceUnit: nil, totalDistanceReason: nil,
            designReason: nil, mileageProgressionNote: nil, coachNote: nil, days: [],
            intensityTotalMinutes: nil, currentVdot: nil, vdotSource: nil,
            createdAt: nil, updatedAt: nil, trainingLoadAnalysis: nil,
            personalizedRecommendations: nil, realTimeAdjustments: nil, apiVersion: "2.0"
        )
    }

    // MARK: - Weekly target

    func test_weeklyTargetUsesCurrentPlanInsteadOfProfileDistance() async {
        let planRepository = MockTrainingPlanV2Repository()
        planRepository.planStatusToReturn = planStatus(currentWeekPlanId: "plan-3")
        planRepository.weeklyPlanV2ToReturn = weeklyPlan(totalDistance: 56)
        let profileRepository = MockUserProfileRepository()
        profileRepository.userToReturn = user(currentWeekDistance: 40)
        DependencyContainer.shared.replace(
            profileRepository as UserProfileRepository,
            for: UserProfileRepository.self
        )
        let vm = makeVM(
            series: RecordingSeriesSource(response: acwrResponse([])),
            planRepository: planRepository
        )

        await vm.revalidate()

        XCTAssertEqual(vm.detail?.value.targetKm, 56)
        XCTAssertEqual(profileRepository.getUserProfileCallCount, 0)
        XCTAssertEqual(planRepository.fetchWeeklyPlanCallCount, 1)
    }

    func test_weeklyTargetIsNilWhenCurrentPlanDoesNotExist() async {
        let planRepository = MockTrainingPlanV2Repository()
        planRepository.planStatusToReturn = planStatus(currentWeekPlanId: nil)
        let profileRepository = MockUserProfileRepository()
        profileRepository.userToReturn = user(currentWeekDistance: 40)
        DependencyContainer.shared.replace(
            profileRepository as UserProfileRepository,
            for: UserProfileRepository.self
        )
        let vm = makeVM(
            series: RecordingSeriesSource(response: acwrResponse([])),
            planRepository: planRepository
        )

        await vm.revalidate()

        XCTAssertNil(vm.detail?.value.targetKm)
        XCTAssertEqual(profileRepository.getUserProfileCallCount, 0)
        XCTAssertEqual(planRepository.fetchWeeklyPlanCallCount, 0)
    }

    // MARK: - hero

    /// hero 大數字是上一完整週的公里數（負荷比降到圖卡標題列），判語仍是後端交的 —— 詳情頁不重新評級。
    func test_heroShowsLastWeekKmAndTheVerdictFromTheCardRow() {
        let bars = [
            App2WeeklyBar(weekStart: "2026-09-14", distanceKm: 27, isCurrentWeek: false, shortLabel: "9/14"),
            App2WeeklyBar(weekStart: "2026-09-21", distanceKm: 5, isCurrentWeek: true, shortLabel: "9/21")
        ]
        let hero = App2VolumeDetailViewModel.hero(insight: volumeInsight(), narrative: nil, bars: bars)
        XCTAssertEqual(hero.valueText, "27 km")
        XCTAssertNotEqual(hero.valueText, "1.7", "負荷比不再是 hero 大數字")
        XCTAssertEqual(hero.verdict, "負荷偏高，近一週比近一個月多 71%，留意")
    }

    /// 上一完整週公里數退副標，用的是後端組好的 `change` 那一句。
    /// **不從長條圖另算一份**：同一個量兩個來源，遲早有一份是舊的。
    func test_theLastCompletedWeekMovesIntoTheSubtitle() {
        let hero = App2VolumeDetailViewModel.hero(
            insight: volumeInsight(), narrative: "本月跑量比上月多 8%", bars: []
        )
        XCTAssertEqual(hero.narrative, "上週 27 km\n本月跑量比上月多 8%")
    }

    /// 大數字換成比值之後，「目標週跑量」不是它的對照量 —— 右側對照整格不畫。
    func test_theTargetIsNoLongerCompadedAgainstTheRatio() {
        let hero = App2VolumeDetailViewModel.hero(insight: volumeInsight(), narrative: nil, bars: [])
        XCTAssertNil(hero.compareLabel)
        XCTAssertNil(hero.compareValue)
    }

    /// 後端兩欄都沒有（`not_computed`）→ 副標整行不出現，不畫空字串。
    func test_noSubtitleWhenTheBackendGaveNeitherLine() {
        let hero = App2VolumeDetailViewModel.hero(
            insight: volumeInsight(value: nil, verdict: "尚未計算", change: nil),
            narrative: nil, bars: []
        )
        XCTAssertNil(hero.narrative)
    }

    // MARK: - 序列

    func test_theSeriesWindowIsThirtyDaysBackFromTheCardsBusinessDay() async {
        let source = RecordingSeriesSource(
            response: acwrResponse([("2026-09-05", 1.39), ("2026-09-06", 1.71)])
        )
        let vm = makeVM(series: source)

        await vm.revalidate()

        XCTAssertEqual(source.requested?.start, "2026-08-08")
        XCTAssertEqual(source.requested?.end, "2026-09-06")
        XCTAssertEqual(vm.detail?.value.acwr?.series.map(\.value), [1.39, 1.71])
        XCTAssertEqual(vm.detail?.value.acwr?.sweetLow, 0.8)
        XCTAssertEqual(vm.detail?.value.acwr?.sweetHigh, 1.3)
    }

    /// 序列讀不到只少那一塊：長條圖與統計照常，頁面不擋（TS-INV-04 的 app 側）。
    func test_aFailedSeriesReadOnlyDropsTheRatioChart() async {
        let source = RecordingSeriesSource(response: acwrResponse([]),
                                           error: URLError(.timedOut))
        let vm = makeVM(series: source)

        await vm.revalidate()

        XCTAssertNil(vm.detail?.value.acwr, "讀失敗不得發布一份空序列冒充結果")
        XCTAssertFalse(vm.detail?.value.bars.isEmpty ?? true, "長條圖是另一條來源，照畫")
        XCTAssertTrue(vm.hasLoaded)
        XCTAssertFalse(vm.isLoading)
    }
}
