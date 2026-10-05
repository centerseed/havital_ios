import XCTest
@testable import paceriz_dev

/// 課表頁收到 workouts 變更後，必須在同一個 app session 讀到最新週跑量。
@MainActor
final class App2PlanWorkoutRefreshTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await CacheEventBus.shared.resetForTesting()
    }

    override func tearDown() async throws {
        await CacheEventBus.shared.resetForTesting()
        try await super.tearDown()
    }

    func test_workoutsChangedRefreshesBeforeRecomputingCurrentWeekVolume() async {
        let planRepository = MockTrainingPlanV2Repository()
        planRepository.planStatusToReturn = planStatus()
        planRepository.overviewToReturn = overview()
        planRepository.weeklyPlanV2ToReturn = weeklyPlan()

        let workoutRepository = MockWorkoutRepository()
        workoutRepository.workoutsToReturn = [workout(id: "old", kilometers: 3)]
        let viewModel = App2PlanViewModel(
            planRepository: planRepository,
            workoutRepository: workoutRepository,
            targetRepository: nil
        )

        await viewModel.revalidate()
        XCTAssertEqual(viewModel.week?.value.completedDistanceKm ?? -1, 3, accuracy: 0.001)

        let freshWorkout = workout(id: "new", kilometers: 8)
        workoutRepository.onRefreshWorkouts = {
            workoutRepository.workoutsToReturn = [freshWorkout]
        }
        CacheEventBus.shared.publish(.dataChanged(.workouts))

        await waitUntil {
            workoutRepository.refreshWorkoutsCallCount == 1
                && viewModel.week?.value.completedDistanceKm == 8
        }

        XCTAssertEqual(workoutRepository.refreshWorkoutsCallCount, 1)
        XCTAssertEqual(viewModel.week?.value.completedDistanceKm ?? -1, 8, accuracy: 0.001)
    }

    func test_workoutsChangedKeepsDisplayedVolumeWhenRefreshFails() async {
        let planRepository = MockTrainingPlanV2Repository()
        planRepository.planStatusToReturn = planStatus()
        planRepository.overviewToReturn = overview()
        planRepository.weeklyPlanV2ToReturn = weeklyPlan()

        let workoutRepository = MockWorkoutRepository()
        workoutRepository.workoutsToReturn = [workout(id: "old", kilometers: 3)]
        let viewModel = App2PlanViewModel(
            planRepository: planRepository,
            workoutRepository: workoutRepository,
            targetRepository: nil
        )

        await viewModel.revalidate()
        XCTAssertEqual(viewModel.week?.value.completedDistanceKm ?? -1, 3, accuracy: 0.001)

        workoutRepository.errorToThrow = TestError.refreshFailed
        CacheEventBus.shared.publish(.dataChanged(.workouts))

        await waitUntil { workoutRepository.refreshWorkoutsCallCount == 1 }

        XCTAssertEqual(viewModel.week?.value.completedDistanceKm ?? -1, 3, accuracy: 0.001)

        await viewModel.revalidate()
        XCTAssertEqual(workoutRepository.refreshWorkoutsCallCount, 2)
        XCTAssertEqual(viewModel.week?.value.completedDistanceKm ?? -1, 3, accuracy: 0.001)

        let freshWorkout = workout(id: "new", kilometers: 8)
        workoutRepository.errorToThrow = nil
        workoutRepository.onRefreshWorkouts = {
            workoutRepository.workoutsToReturn = [freshWorkout]
        }
        await viewModel.revalidate()

        await waitUntil {
            workoutRepository.refreshWorkoutsCallCount == 3
                && viewModel.week?.value.completedDistanceKm == 8
        }

        XCTAssertEqual(workoutRepository.refreshWorkoutsCallCount, 3)
        XCTAssertEqual(viewModel.week?.value.completedDistanceKm ?? -1, 8, accuracy: 0.001)
    }

    func test_weeklyPlanFailureWithoutExistingWeekLeavesNilAndMarksFailure() async {
        let planRepository = MockTrainingPlanV2Repository()
        planRepository.planStatusToReturn = planStatus()
        planRepository.cachedWeeklyPlansByWeek = [:]
        planRepository.fetchWeeklyPlanErrorToThrow = TestError.refreshFailed

        let viewModel = App2PlanViewModel(
            planRepository: planRepository,
            workoutRepository: MockWorkoutRepository(),
            targetRepository: nil
        )

        await viewModel.revalidate()

        XCTAssertNil(viewModel.week)
        XCTAssertEqual(viewModel.loadState, .failed)
    }

    func test_weeklyPlanNotGeneratedLeavesNilAndMarksNotGenerated() async {
        let planRepository = MockTrainingPlanV2Repository()
        planRepository.planStatusToReturn = planStatus(
            nextAction: "create_plan",
            currentWeekPlanId: nil
        )

        let viewModel = App2PlanViewModel(
            planRepository: planRepository,
            workoutRepository: MockWorkoutRepository(),
            targetRepository: nil
        )

        await viewModel.revalidate()

        XCTAssertNil(viewModel.week)
        XCTAssertFalse(viewModel.isPlanGenerated)
        XCTAssertEqual(viewModel.loadState, .notGenerated)
    }

    func test_weeklyPlanFailureWithExistingWeekKeepsSWRData() async {
        let planRepository = MockTrainingPlanV2Repository()
        planRepository.planStatusToReturn = planStatus()
        planRepository.weeklyPlanV2ToReturn = weeklyPlan()

        let viewModel = App2PlanViewModel(
            planRepository: planRepository,
            workoutRepository: MockWorkoutRepository(),
            targetRepository: nil
        )

        await viewModel.revalidate()
        let distanceBeforeFailure = viewModel.week?.value.targetDistanceKm
        planRepository.fetchWeeklyPlanErrorToThrow = TestError.refreshFailed

        await viewModel.revalidate()

        XCTAssertEqual(viewModel.week?.value.targetDistanceKm, distanceBeforeFailure)
        XCTAssertEqual(viewModel.loadState, .loaded)
    }

    private func planStatus(
        nextAction: String = "view_plan",
        currentWeekPlanId: String? = "plan-1"
    ) -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: 1,
            totalWeeks: 4,
            nextAction: nextAction,
            canGenerateNextWeek: false,
            currentWeekPlanId: currentWeekPlanId,
            previousWeekSummaryId: nil,
            targetType: "race_run",
            methodologyId: "paceriz",
            nextWeekInfo: nil,
            metadata: nil
        )
    }

    private func overview() -> PlanOverviewV2 {
        PlanOverviewV2(
            id: "overview-1", targetId: nil, targetType: "race_run", targetDescription: nil,
            methodologyId: "paceriz", totalWeeks: 4, startFromStage: "base",
            raceDate: nil, distanceKm: nil, distanceKmDisplay: nil, distanceUnit: nil,
            targetPace: nil, targetTime: nil, isMainRace: nil, targetName: nil,
            methodologyOverview: nil, targetEvaluate: nil, approachSummary: nil,
            trainingStages: [], milestones: [], createdAt: Date(),
            methodologyVersion: nil, milestoneBasis: nil
        )
    }

    private func weeklyPlan() -> WeeklyPlanV2 {
        WeeklyPlanV2(
            planId: "plan-1", weekOfTraining: 1, id: "plan-1",
            purpose: "base", weekOfPlan: 1, totalWeeks: 4, totalDistance: 42,
            totalDistanceDisplay: nil, totalDistanceUnit: nil, totalDistanceReason: nil,
            designReason: nil, mileageProgressionNote: nil, coachNote: nil, days: [],
            intensityTotalMinutes: nil, currentVdot: nil, vdotSource: nil,
            createdAt: Date(), updatedAt: Date(), trainingLoadAnalysis: nil,
            personalizedRecommendations: nil, realTimeAdjustments: nil, apiVersion: "2.0"
        )
    }

    private func workout(id: String, kilometers: Double) -> WorkoutV2 {
        WorkoutV2(
            id: id, provider: "garmin", activityType: "running",
            startTimeUtc: "2026-09-07T00:00:00Z", endTimeUtc: nil,
            durationSeconds: 1, distanceMeters: kilometers * 1000,
            distanceDisplay: nil, distanceUnit: nil, deviceName: nil,
            basicMetrics: nil, advancedMetrics: nil, createdAt: nil,
            schemaVersion: nil, storagePath: nil, dailyPlanSummary: nil,
            aiSummary: nil, shareCardContent: nil
        )
    }

    private static func waitUntil(
        timeout: TimeInterval = 5,
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private enum TestError: Error {
        case refreshFailed
    }
}
