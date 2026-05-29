import XCTest
@testable import paceriz_dev

@MainActor
final class TrainingPlanV2TargetUpdateTests: XCTestCase {
    private var sut: TrainingPlanV2ViewModel!
    private var repository: MockTrainingPlanV2Repository!
    private var workoutRepository: MockWorkoutRepository!

    override func setUp() async throws {
        try await super.setUp()

        repository = MockTrainingPlanV2Repository()
        workoutRepository = MockWorkoutRepository()

        let container = DependencyContainer.shared
        if !container.isRegistered(TrainingVersionRouter.self) {
            container.registerTrainingVersionRouter()
        }
        if !container.isRegistered(AchievementRepository.self) {
            container.registerAchievementModule()
        }

        sut = TrainingPlanV2ViewModel(
            repository: repository,
            workoutRepository: workoutRepository,
            versionRouter: container.resolve(),
            achievementRepository: container.resolve()
        )
    }

    override func tearDown() async throws {
        sut = nil
        repository = nil
        workoutRepository = nil
        try await super.tearDown()
    }

    func test_refreshOverviewAfterTargetUpdate_clearsOverviewCacheAndForceRefreshesOverview() async throws {
        let overview = try loadOverviewFixture(named: "race_run_paceriz")
        repository.overviewToReturn = overview
        repository.planStatusToReturn = PlanStatusV2Response(
            currentWeek: 1,
            totalWeeks: overview.totalWeeks,
            nextAction: "create_plan",
            canGenerateNextWeek: true,
            currentWeekPlanId: nil,
            previousWeekSummaryId: nil,
            targetType: overview.targetType,
            methodologyId: overview.methodologyId,
            nextWeekInfo: nil,
            metadata: nil
        )

        await sut.refreshOverviewAfterTargetUpdate()

        XCTAssertEqual(repository.clearOverviewCacheCallCount, 1)
        XCTAssertEqual(repository.refreshOverviewCallCount, 1)
        XCTAssertEqual(sut.loader.planOverview?.id, overview.id)
        XCTAssertEqual(sut.loader.trainingPlanName, overview.targetName ?? "訓練計畫")
    }

    func test_pollPlanOverviewRegeneration_refreshesUntilCompleted() async throws {
        let initial = try loadOverviewFixture(named: "race_run_paceriz")
        let queued = initial.withRegenerationStatus("queued")
        let completed = initial.withRegenerationStatus("completed")
        repository.refreshOverviewResults = [queued, completed]
        repository.weeklyPreviewToReturn = WeeklyPreviewV2(
            id: initial.id,
            methodologyId: initial.methodologyId ?? "paceriz",
            weeks: [],
            createdAt: nil,
            updatedAt: nil
        )
        repository.planStatusToReturn = PlanStatusV2Response(
            currentWeek: 1,
            totalWeeks: initial.totalWeeks,
            nextAction: "create_plan",
            canGenerateNextWeek: true,
            currentWeekPlanId: nil,
            previousWeekSummaryId: nil,
            targetType: initial.targetType,
            methodologyId: initial.methodologyId,
            nextWeekInfo: nil,
            metadata: nil
        )

        await sut.pollPlanOverviewRegeneration(overviewId: initial.id, pollAfterSeconds: 0)

        XCTAssertEqual(repository.clearOverviewCacheCallCount, 2)
        XCTAssertEqual(repository.refreshOverviewCallCount, 2)
        XCTAssertEqual(repository.refreshWeeklyPreviewCallCount, 1)
        XCTAssertEqual(repository.getWeeklyPreviewCallCount, 0)
        XCTAssertEqual(sut.loader.planOverview?.regenerationStatus, "completed")
        XCTAssertEqual(sut.successToast, NSLocalizedString("training.plan_overview_updated", comment: "訓練總覽已更新"))
    }

    private func loadOverviewFixture(named name: String) throws -> PlanOverviewV2 {
        let data = try Self.loadFixtureData(directory: "PlanOverview", name: name)
        let dto = try JSONDecoder().decode(PlanOverviewV2DTO.self, from: data)
        return PlanOverviewV2Mapper.toEntity(from: dto)
    }

    private static func loadFixtureData(directory: String, name: String) throws -> Data {
        let testDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = testDir
            .appendingPathComponent("APISchema/Fixtures/\(directory)/\(name).json")
        return try Data(contentsOf: fixtureURL)
    }
}

private extension PlanOverviewV2 {
    func withRegenerationStatus(_ status: String) -> PlanOverviewV2 {
        PlanOverviewV2(
            id: id,
            targetId: targetId,
            targetType: targetType,
            targetDescription: targetDescription,
            methodologyId: methodologyId,
            totalWeeks: totalWeeks,
            startFromStage: startFromStage,
            raceDate: raceDate,
            distanceKm: distanceKm,
            distanceKmDisplay: distanceKmDisplay,
            distanceUnit: distanceUnit,
            targetPace: targetPace,
            targetTime: targetTime,
            isMainRace: isMainRace,
            targetName: targetName,
            methodologyOverview: methodologyOverview,
            targetEvaluate: targetEvaluate,
            approachSummary: approachSummary,
            trainingStages: trainingStages,
            milestones: milestones,
            createdAt: createdAt,
            methodologyVersion: methodologyVersion,
            milestoneBasis: milestoneBasis,
            regenerationStatus: status,
            regenerationReason: regenerationReason,
            regenerationErrorMessage: regenerationErrorMessage
        )
    }
}
