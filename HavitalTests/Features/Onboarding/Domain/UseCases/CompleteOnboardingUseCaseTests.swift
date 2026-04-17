//
//  CompleteOnboardingUseCaseTests.swift
//  HavitalTests
//
//  Unit tests for CompleteOnboardingUseCase
//

import XCTest
@testable import paceriz_dev

final class CompleteOnboardingUseCaseTests: XCTestCase {

    // MARK: - Properties

    private var sut: CompleteOnboardingUseCase!
    private var mockRepository: MockTrainingPlanRepository!
    private var mockV2Repository: MockTrainingPlanV2Repository!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockRepository = MockTrainingPlanRepository()
        mockV2Repository = MockTrainingPlanV2Repository()
        sut = CompleteOnboardingUseCase(
            trainingPlanRepository: mockRepository,
            trainingPlanV2Repository: mockV2Repository
        )
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        mockV2Repository = nil
        super.tearDown()
    }

    // MARK: - Helper

    /// Create a V1-style Input (no V2 parameters)
    private func makeV1Input(
        startFromStage: String? = nil,
        isBeginner: Bool = false,
        isReonboarding: Bool = false
    ) -> CompleteOnboardingUseCase.Input {
        CompleteOnboardingUseCase.Input(
            startFromStage: startFromStage,
            isBeginner: isBeginner,
            isReonboarding: isReonboarding,
            targetTypeId: nil,
            targetId: nil,
            methodologyId: nil,
            trainingWeeks: nil,
            availableDays: nil,
            previewOverviewId: nil
        )
    }

    private func makeV2Input(
        startFromStage: String? = "build",
        previewOverviewId: String? = "overview_1"
    ) -> CompleteOnboardingUseCase.Input {
        CompleteOnboardingUseCase.Input(
            startFromStage: startFromStage,
            isBeginner: false,
            isReonboarding: false,
            targetTypeId: "race_run",
            targetId: "target_1",
            methodologyId: "paceriz",
            trainingWeeks: nil,
            availableDays: 4,
            previewOverviewId: previewOverviewId
        )
    }

    private func makeOverview(
        id: String = "overview_1",
        totalWeeks: Int = 5,
        startFromStage: String? = "build"
    ) -> PlanOverviewV2 {
        PlanOverviewV2(
            id: id,
            targetId: "target_1",
            targetType: "race_run",
            targetDescription: nil,
            methodologyId: "paceriz",
            totalWeeks: totalWeeks,
            startFromStage: startFromStage,
            raceDate: Int(Date().addingTimeInterval(86400 * 35).timeIntervalSince1970),
            distanceKm: 21.0975,
            distanceKmDisplay: nil,
            distanceUnit: nil,
            targetPace: "5:30",
            targetTime: 7200,
            isMainRace: true,
            targetName: "Test Race",
            methodologyOverview: nil,
            targetEvaluate: nil,
            approachSummary: nil,
            trainingStages: [],
            milestones: [],
            createdAt: Date(),
            methodologyVersion: nil,
            milestoneBasis: nil
        )
    }

    private func makeWeeklyPlanV2(id: String = "plan_1") -> WeeklyPlanV2 {
        WeeklyPlanV2(
            planId: id,
            weekOfTraining: 1,
            id: id,
            purpose: "Test weekly plan",
            weekOfPlan: 1,
            totalWeeks: 5,
            totalDistance: 30,
            totalDistanceDisplay: nil,
            totalDistanceUnit: nil,
            totalDistanceReason: nil,
            designReason: ["Test"],
            days: [],
            intensityTotalMinutes: nil,
            createdAt: Date(),
            updatedAt: Date(),
            trainingLoadAnalysis: nil,
            personalizedRecommendations: nil,
            realTimeAdjustments: nil,
            apiVersion: "2.0"
        )
    }

    // MARK: - Success Cases

    func test_execute_createsWeeklyPlan_success() async throws {
        // Given
        let expectedPlan = TrainingPlanTestFixtures.weeklyPlan1
        mockRepository.weeklyPlanToReturn = expectedPlan

        let input = makeV1Input()

        // When
        let output = try await sut.execute(input: input)

        // Then
        XCTAssertEqual(output.weeklyPlan?.id, expectedPlan.id)
        XCTAssertEqual(output.wasReonboarding, false)
        XCTAssertEqual(mockRepository.createWeeklyPlanCallCount, 1)
    }

    func test_execute_passesCorrectParameters_toRepository() async throws {
        // Given
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1

        let input = makeV1Input(startFromStage: "stage_2", isBeginner: true)

        // When
        _ = try await sut.execute(input: input)

        // Then
        XCTAssertEqual(mockRepository.createWeeklyPlanCallCount, 1)
    }

    func test_execute_handlesReonboardingMode() async throws {
        // Given
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1

        let input = makeV1Input(isReonboarding: true)

        // When
        let output = try await sut.execute(input: input)

        // Then
        XCTAssertEqual(output.wasReonboarding, true)
        XCTAssertEqual(mockRepository.createWeeklyPlanCallCount, 1)
    }

    func test_execute_handlesBeginnerMode() async throws {
        // Given
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1

        let input = makeV1Input(isBeginner: true)

        // When
        let output = try await sut.execute(input: input)

        // Then
        XCTAssertEqual(output.weeklyPlan?.id, TrainingPlanTestFixtures.weeklyPlan1.id)
        XCTAssertEqual(output.wasReonboarding, false)
    }

    // MARK: - Error Cases

    func test_execute_throwsError_whenPlanCreationFails() async {
        // Given
        mockRepository.errorToThrow = TrainingPlanError.noPlan

        let input = makeV1Input()

        // When / Then
        do {
            _ = try await sut.execute(input: input)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is OnboardingError)
        }
    }

    func test_execute_throwsError_whenRepositoryReturnsNil() async {
        // Given
        mockRepository.weeklyPlanToReturn = nil

        let input = makeV1Input()

        // When / Then
        do {
            _ = try await sut.execute(input: input)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is OnboardingError)
        }
    }

    // MARK: - Output Verification

    func test_execute_returnsCorrectOutput_withStartFromStage() async throws {
        // Given
        let expectedPlan = TrainingPlanTestFixtures.weeklyPlan2
        mockRepository.weeklyPlanToReturn = expectedPlan

        let input = makeV1Input(startFromStage: "advanced_stage", isReonboarding: true)

        // When
        let output = try await sut.execute(input: input)

        // Then
        XCTAssertEqual(output.weeklyPlan?.id, expectedPlan.id)
        XCTAssertEqual(output.weeklyPlan?.weekOfPlan, expectedPlan.weekOfPlan)
        XCTAssertEqual(output.wasReonboarding, true)
    }

    func test_execute_v2RacePlanExpanderFailure_retriesWithFallbackStage() async throws {
        // Given
        mockV2Repository.overviewToReturn = makeOverview(startFromStage: "build")
        mockV2Repository.weeklyPlanV2ToReturn = makeWeeklyPlanV2()
        mockV2Repository.generateWeeklyPlanErrors = [
            DomainError.badRequest("{\"error\":\"PlanExpander 展開失敗\"}")
        ]

        // When
        let output = try await sut.execute(input: makeV2Input())

        // Then
        XCTAssertEqual(output.weeklyPlanV2?.id, "plan_1")
        XCTAssertEqual(mockV2Repository.generateWeeklyPlanCallCount, 2)
        XCTAssertEqual(mockV2Repository.createOverviewForRaceCallCount, 0)
        XCTAssertEqual(mockV2Repository.updateOverviewCallCount, 1)
        XCTAssertEqual(mockV2Repository.lastUpdatedOverviewId, "overview_1")
        XCTAssertEqual(mockV2Repository.lastUpdatedOverviewStartFromStage, "peak")
        XCTAssertEqual(mockV2Repository.lastUpdatedOverviewMethodologyId, "paceriz")
    }

    func test_execute_v2NonPlanExpanderFailure_doesNotRetryFallbackStage() async {
        // Given
        mockV2Repository.overviewToReturn = makeOverview(startFromStage: "build")
        mockV2Repository.generateWeeklyPlanErrors = [
            DomainError.badRequest("{\"error\":\"subscription required\"}")
        ]

        // When / Then
        do {
            _ = try await sut.execute(input: makeV2Input())
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is OnboardingError)
            XCTAssertEqual(mockV2Repository.generateWeeklyPlanCallCount, 1)
            XCTAssertEqual(mockV2Repository.updateOverviewCallCount, 0)
        }
    }
}
